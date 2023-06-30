# Create VM instances in multi regions

A ```bash``` shell script that deploys VM instances of a single type to multiple regions.
The goal is to minimize repetitive tasks.

## Short description

There are 7 files in total.
It consists of 1 configuration file and 6 shell script files.
Start by creating a VPC within your project,
A script is also included to delete everything you create.
The parts suitable for each purpose are divided into files so that only the necessary parts can be used separately. 

Individual files do the following:

- ```main.env``` Contains environment variables referenced by all shell scripts.

1. ```create-vpc-subnet.sh``` Create a VPC and subnets.
1. ```create-firewall-rules.sh``` Write firewall rules.
1. ```create-vm-instances.sh``` Create VM instances.
1. ```delete-vm-instances.sh``` Delete the VM instances created above.
1. ```delete-firewall-rules.sh``` Delete the firewall rule created above.
1. ```delete-vpc.sh``` Delete the VPC and sub-components created above.

## About individual scripts

### Set up environment

```main.env``` treats the following as variables, and needs input.
Variables that are used multiple times in individual scripts are organized into a single file to avoid repetitive editing.

```bash
vpcName=YOUR_VPC_NAME
vmType=n2-highmem-16
targetZones=('asia-northeast3-a' 'asia-south1-a' 'europe-west2-a' 'me-west1-a' 'us-central1-a' 'us-south1-a' 'us-west1-a' 'us-west2-a')
projectName=YOUR_PROJECT_NAME
```

* Replace ```YOUR_VPC_NAME``` with your desired VPC name.
* `n2-highmem-16` is entered as an example. Change to the desired VM instance type. Detailed instructions are below.
* List the deployment target zones after ```targetZones={``` as in the example above. There must be at least one. Detailed instructions are below.
* Replace ```YOUR_PROJECT_NAME``` with your desired project name.

#### VM instance types

The types of VM instances can be found on Google Cloud's [public website]("https://cloud.google.com/compute/docs/machine-resource"). However, there is also a way to harmonize directly in the CLI environment. The following command will help.
```gcloud compute machine-types list --project $projectName```

The above command produces screen output as shown below.

```bash
NAME              ZONE                       CPUS  MEMORY_GB  DEPRECATED
...
c2d-highcpu-112   us-central1-a              112   224.00
c2d-highcpu-16    us-central1-a              16    32.00
c2d-highcpu-2     us-central1-a              2     4.00
...
n1-ultramem-80    asia-northeast3-b          80    1922.00    DEPRECATED
n2-highcpu-16     asia-northeast3-b          16    16.00
...
```

The information output tells you what types of VM instances can be created in a particular zone. It also outputs the number of vCPUs and amount of memory.
The VM instance type that can be input to ```main.env``` must use the representation in the first column of the output above.

#### Regions and zones

If you want to search the regions that can be operated within the current user's settings,
The following commands are suitable.
```gcloud compute regions list --project $projectName```

If you want to know even the zones, you can change the previous command slightly.
```gcloud compute zones list --project $projectName``` the outputs are:

```bash
NAME                       REGION                   STATUS  NEXT_MAINTENANCE  TURNDOWN_DATE
us-east1-b                 us-east1                 UP
us-east1-c                 us-east1                 UP
us-east1-d                 us-east1                 UP
us-east4-c                 us-east4                 UP
us-east4-b                 us-east4                 UP
us-east4-a                 us-east4                 UP
us-central1-c              us-central1              UP
us-central1-a              us-central1              UP
us-central1-f              us-central1              UP
us-central1-b              us-central1              UP
us-west1-b                 us-west1                 UP
us-west1-c                 us-west1                 UP
us-west1-a                 us-west1                 UP
...
```

You can use the value in the second column of the result of looking up the VM instance type earlier,
You can also use the zone name output from the command above. It's the same value.

### Create VPC

```create-vpc-subnet.sh``` is responsible for creating a VPC and subnets.
```bash
#!/bin/bash
source ./main.env

gcloud compute networks create $vpcName \
  --subnet-mode=auto
```

Google Cloud's VPCs will cover all regions worldwide.
There is no need to create a VPC for each region. Region distinction is made by subnet.
So very useful and convenient.

The script is set to ```subnet-mode=auto```.
```auto``` automatically creates a subnet.
If you want to configure a subnet elaborately, you can change this part.

> See more:   
[```gcloud compute networks create```](https://cloud.google.com/sdk/gcloud/reference/compute/networks/create)  
[```gcloud compute networks subnets create```](https://cloud.google.com/sdk/gcloud/reference/compute/networks/subnets/create) 

### Firewall settings

```create-firewall-rules.sh``` is to write firewall rules to the VPC.

In this example, the following TCP ports are opened with three rules.

* SSH
* ICMP

The setting of the rule in the shell script has the following meaning.

* ```allow-ssh-ingress-from-iap```: To ensure access using IAP, access from ```35.235.240.0/20``` to ```TCP:22``` is allowed.
* ```allow-ssh-in-private```: Allow ```TCP:22``` for SSH connection between VM instances within the CIDR range of the subnet, which is a limited range.
* ```allow-pinging-in-private```: ```ICMP`` is allowed within the CIDR range of the subnet to check communication between VM instances.

A detailed description of setting up firewall rules for Identity-Aware Proxy (IAP) can be found in [Google Cloud Public Web Documentation](https://cloud.google.com/iap/docs/using-tcp-forwarding#create-firewall-rule ).

If you use IAP, you do not need to deploy additional features such as bastion while taking the path to connect to the VM instance with high security.
```gcloud compute ssh $vmInstanceName --zone $zone``` can be used to access ssh from the user's client.

Utilize [Auto mode IPv4 ranges]("https://cloud.google.com/vpc/docs/subnets#ip-ranges") for private access range.

### Create VM instances

```create-vm-instances.sh```creates VM instances.

A ```for``` statement that reads the list of zones in ```main.env```, also reads the VM instance type, and creates VM instances one by one using the predefined VPC name and project name.

```bash
#!/bin/bash
source ./main.env

for zoneName in "${targetZones[@]}"
do
  gcloud compute instances create $zoneName-vm \
  --machine-type=$vmType \
  --network=$vpcName \
  --no-address \
  --project=$projectName \
  --shielded-secure-boot \
  --zone=$zoneName
done
```

VM instances that are repeatedly created in each region took the form of taking the name of the creation zone. This is expressed as ```create $zoneName-vm \``` on line 6.

```---no-address``` in the 9th line means that the VM instance will not be given a public IP. When using this option, a private IP is dynamically assigned.

#### Startup scripts 

You can create a VM instance and add an option to make it behave like the OS's RC scripts when it boots. You can use ```--metadata=startup-script='...'```, and the following is an example.

```bash
  --metadata=startup-script='
        #!/bin/bash
        useradd -m user1
        echo user1:saUca1zk1mOyY | chpasswd -e
        usermod -aG google-sudoers user1
        sed -i "s/^PasswordAuthentication .*/PasswordAuthentication yes/" /etc/ssh/sshd_config
        systemctl reload sshd
        mkdir /mnt/ram-disk
        mount -t tmpfs -o size=110g tmpfs /mnt/ram-disk
        chown -R user1 /mnt/ram-disk
        '
```

the aboves: 
- ```useradd -m user1``` add a new user named user1
- ```echo user1:... | chpasswd -e``` set login password for user1
- ```usermod -aG...``` assign sudo rights to user1
- ```sed -i "s/... /etc/ssh/sshd_config``` allow ssh access with login password
- ```systemctl reload sshd``` restart the daemon to read the above settings
- ```mkdir /mnt/ram-disk``` create /mnt/ram-disk directory
- ```mount -t tmpfs ... /mnt/ram-disk``` mount the die memory disk on /mnt/ram-disk directory
- ```chown -R user1 /mnt/ram-disk``` set ownership of the directory to user1

A user's login password can be created in a number of ways. The method I used is the classic method. ```perl -e 'print crypt("helloworld", "salt"),"\n"'```

### The rest

Scripts not described have the role of deleting the ones created above.
Delete in the reverse order of creation.
