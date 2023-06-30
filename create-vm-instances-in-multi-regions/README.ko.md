# Create VM instances in multi regions

단일 유형의 VM 인스턴스를 여러 리전에 배포하는 ```bash``` 쉘 스크립트입니다.
반복적인 작업을 최소화하는 것에 목적이 있습니다.

Read this in other language: [English](README.md)

## 대략적인 설명

총 7개의 파일입니다.
1개의 환경설정 파일과 6개의 쉘 스크립트 파일로 이루어져 있습니다.
사용자의 프로젝트 내에 VPC를 생성하는 데에서부터 시작하고,
생성한 모든 것을 삭제하는 스크립트도 포함되어 있습니다. 
각 목적에 맞는 부분은 파일로 구분하여 필요한 부분만 따로 사용할 수 있도록 했습니다. 

개별 파일들은 다음의 역할을 합니다.

- ```main.env``` 모든 쉘 스크립트들이 참조하는 환경변수들을 수록하고 있습니다.

1. ```create-vpc-subnet.sh``` VPC와 subnet을 만듭니다.
1. ```create-firewall-rules.sh``` 방화벽 규칙을 작성합니다.
1. ```create-vm-instances.sh``` VM 인스턴스들을 생성합니다.
1. ```delete-vm-instances.sh``` 위에서 작성한 VM 인스턴스들을 삭제합니다.
1. ```delete-firewall-rules.sh``` 위에서 작성한 방화벽 규칙을 삭제합니다.
1. ```delete-vpc.sh``` 위에서 작성한 VPC 및 하위 구성요소를 삭제합니다.

## 개별 스크립트에 대하여

### 환경을 설정하다

```main.env```에는 다음을 변수로 처리하고, 입력을 원합니다.  
개별 스크립트에서 여러 번 사용되는 변수들을 하나의 파일로 정리하여 반복적인 편집을 회피할 수 있게 했습니다.

```bash
vpcName=YOUR_VPC_NAME
vmType=n2-highmem-16
targetZones=('asia-northeast3-a' 'asia-south1-a' 'europe-west2-a' 'me-west1-a' 'us-central1-a' 'us-south1-a' 'us-west1-a' 'us-west2-a')
projectName=YOUR_PROJECT_NAME
```

* 원하는 VPC 이름으로 ```YOUR_VPC_NAME```을 대체합니다.
* `n2-highmem-16`은 예제로 입력해 둔 것입니다. 원하는 VM 인스턴스 유형으로 변경합니다. 아래에 상세한 안내가 있습니다.
* 배포 대상 영역을 ```targetZones={``` 이후에 위 예제와 같이 나열합니다. 1개 이상 있어야 합니다. 아래에 상세한 안내가 있습니다.
* ```YOUR_PROJECT_NAME```을 원하는 프로젝트 이름으로 대체합니다.

#### VM 인스턴스 유형

VM 인스턴스의 유형은 Google Cloud의 [공개 웹 사이트]("https://cloud.google.com/compute/docs/machine-resource")에서 찾아 볼 수 있습니다. 하지만, CLI 환경에서 직접 조화하는 방법도 있습니다. 다음의 명령이 도움이 됩니다.  
```gcloud compute machine-types list --project $projectName```

위 명령은 아래와 같이 화면 출력을 만듭니다.

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

출력되는 정보는 특정 영역에서 생성 가능한 VM 인스턴스 유형을 알려 줍니다. 그리고 vCPU 개수와 메모리량도 출력합니다. 
```main.env```에 입력할 수 있는 VM 인스턴스 타입은 위 출력의 첫번째 열에 있는 표현 방식을 사용해야 합니다.

#### 리전과 영역 

현재 사용자의 설정 내에서 운영 가능한 리전(regions)을 조회하고 싶다면,
다음의 명령이 적당합니다.
```gcloud compute regions list --project $projectName```

영역(zones)까지 알고 싶다면, 앞선 명령어를 조금만 변경하면 됩니다.
```gcloud compute zones list --project $projectName```
출력값은 다음과 같습니다:

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

앞서 VM 인스턴스 유형을 조회한 결과의 두 번째 열의 값을 사용해도 되고,
위 명령에서 출력되는 영역 이름을 사용해도 됩니다. 같은 값입니다. 

### VPC를 작성

```create-vpc-subnet.sh```은 VPC와 subnet들을 만드는 역할을 합니다.  
```bash
#!/bin/bash
source ./main.env

gcloud compute networks create $vpcName \
  --subnet-mode=auto
```

Google Cloud의 VPC는 전 세계 모든 리전을 포함하게 됩니다.
리전 마다 VPC를 작성할 필요가 없습니다. 리전 구분은 subnet에서 합니다.
그래서 매우 유용하고 편리합니다.

해당 스크립트는 ```subnet-mode=auto```로 설정해 두었습니다.
```auto```는 subnet을 자동으로 생성해 주는 것입니다.
만약 정교하게 subnet을 구성하고 싶다면, 이 부분을 변경하면 되겠습니다.

> 참조:   
[```gcloud compute networks create```](https://cloud.google.com/sdk/gcloud/reference/compute/networks/create)  
[```gcloud compute networks subnets create```](https://cloud.google.com/sdk/gcloud/reference/compute/networks/subnets/create) 

### Firewall 설정

```create-firewall-rules.sh```은 firewall 규칙을 VPC에 기입하는 것입니다.

본 예제에서는 3가지 규칙으로 다음의 TCP ports를 열었습니다.

* SSH
* ICMP

쉘 스크립트 내 규칙에 대한 설정은 다음의 의미를 담고 있습니다.

* ```allow-ssh-ingress-from-iap```: IAP를 활용한 접속을 보장하기 위하여 ```35.235.240.0/20```로부터 ```TCP:22```로 접속하는 것을 허용
* ```allow-ssh-in-private```: VM 인스턴스 간의 SSH 연결을 위한 ```TCP:22```를 한정된 범위, subnet의 CIDR 범위 내에서 허용
* ```allow-pinging-in-private```: VM 인스턴스 상호 간의 통신 가능을 확인을 위한, subnet의 CIDR 범위 내에서 ```ICMP``` 허용

IAP(Identity-Aware Proxy)를 위한 방화벽 규칙 설정에 대한 상세한 설명은 [Google Cloud 공개 웹 문서](https://cloud.google.com/iap/docs/using-tcp-forwarding#create-firewall-rule)에서 찾아볼 수 있습니다.

IAP를 활용하시면, VM 인스턴스에 접속하는 경로를 보안성 높게 가져가면서 bastion과 같은 부가적인 기능 배포가 필요하지 않습니다.
```gcloud compute ssh $vmInstanceName --zone $zone```과 같은 문법으로 사용자의 클라이언트에서 ssh 접속을 할 수 있습니다.

[자동으로 만들어진 subnet의 CIDR 범위는 미리 정의]("https://cloud.google.com/vpc/docs/subnets#ip-ranges")되어 있습니다. 그 CIDR 블록을 활용합니다.

### VM 인스턴스들 작성

```create-vm-instances.sh```은 실제 VM 인스턴스들을 만듭니다.

```main.env```에 있는 영역(zones) 목록을 읽어 들이고, VM 인스턴스 유형도 읽어 들여, 사전에 정의되어 있는 VPC 이름과 프로젝트 이름을 사용하여 VM 인스턴스들을 하나씩 만들어내는 ```for``` 문으로 구성되어 있습니다.

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

각 리전에 반복 생성되는 VM 인스턴스들은 생성 영역(Zone)의 이름을 따오는 형식을 취했습니다. 이것은 6번째 행에 ```create $zoneName-vm \```으로 표현되어 있습니다.

9번째 행의 ```---no-address```는 VM 인스턴스에 Public IP를 부여하지 않겠다는 의미입니다. 이 옵션을 사용하면, Private IP가 동적으로 할당됩니다.

#### Startup 스크립트 

VM 인스턴스를 만들고, 부팅하게 될 때 OS의 RC 스크립트들처럼 동작시키는 옵션을 부가할 수 있습니다. ```--metadata=startup-script='...'```을 사용하면 되는데, 아래는 한 예제입니다. 

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

위 내용은 
- ```useradd -m user1``` user1 이라는 새로운 사용자 추가
- ```echo user1:... | chpasswd -e``` user1의 로그인 패스워드 설정
- ```usermod -aG...``` user1에 sudo 권한 할당
- ```sed -i "s/... /etc/ssh/sshd_config``` 로그인 패스워드로 ssh 접속 허용
- ```systemctl reload sshd``` 위 설정을 읽어 들이도록 데몬 재시작
- ```mkdir /mnt/ram-disk``` /mnt/ram-disk 디렉토리 생성
- ```mount -t tmpfs ... /mnt/ram-disk``` /mnt/ram-disk 디렉토리에 메모리 디스크 마운트 
- ```chown -R user1 /mnt/ram-disk``` 해당 디렉토리의 소유권한을 user1으로 설정
와 같습니다. 

사용자의 로그인 암호는 다양한 방법으로 만들어 낼 수 있습니다. 제가 사용한 방법은 고전적인 방식입니다. ```perl -e 'print crypt("helloworld", "salt"),"\n"'```

### 나머지 것들

설명하지 않은 스크립트들은 위에서 작성한 것들을 삭제하는 역할을 가지고 있습니다.
생성의 역순으로 삭제하면 되겠습니다.
