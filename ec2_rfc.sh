#!/bin/bash
Description=$1
VpcID=$2
Name=$3
InstanceAmiId=$4
InstanceSubnetId=$5
InstanceDetailedMonitoring=$6
InstanceEBSOptimized=$7
InstanceProfile=$8
InstanceRootVolumeIops=$9
InstanceRootVolumeName=${10}
InstanceRootVolumeSize=${11}
InstanceRootVolumeType=${12}
InstanceType=${13}
InstanceUserData=${14}


#RUN_ID=` date +%s | sha256sum | base64 | head -c 6 | awk '{print tolower($0)}'`
#echo "starting run ID: $RUN_ID"

StackRFC='{
	"ChangeTypeId": "ct-14027q0sjyt1h",
	"ChangeTypeVersion": "3.0",
	"Description": "Creating Testing Stack",
	"WorstCaseScenario": "RFC fails",
	"ImplementationPlan": "Automated Provisioning",
	"RollbackPlan": "Manual rollback",
	"ExpectedOutcome": "Stack Provision successfull",
	"Title": "Stack Provision",
	"RequestedStartTime": "START_TIME",
	"RequestedEndTime": "END_TIME"
}'

StackParams='{
        "Description":" '$Description'",
        "VpcId": "'$VpcID'",
	 "Tags": [
    {
      "Value": "'${Name}'",
      "Key": "Name"
    },
    {
      "Value": "SampleApp",
      "Key": "Application"
    },
    {
      "Value": "1.8",
      "Key": "Application Version"
    },
    {
      "Value": "DevTest T1 Ireland",
      "Key": "Environment Type"
    },
    {
      "Value": "PROJECT",
      "Key": "Environment Use"
    },
    {
      "Value": "DevOps",
      "Key": "Owner"
    },
    {
      "Value": "Cloud Migration",
      "Key": "Business Domain"
    }
  	],
        "Name": "'$Name'",
	"TimeoutInMinutes": 60,
        "Parameters": {
		"InstanceAmiId": "'$InstanceAmiId'",
        	"InstanceSubnetId": "'$InstanceSubnetId'",
        	"InstanceDetailedMonitoring": '$InstanceDetailedMonitoring',
	        "InstanceEBSOptimized": '$InstanceEBSOptimized',
	        "InstanceProfile": "'$InstanceProfile'",
	        "InstanceRootVolumeIops": '$InstanceRootVolumeIops',
	        "InstanceRootVolumeName": "'$InstanceRootVolumeName'",
	        "InstanceRootVolumeSize": '$InstanceRootVolumeSize',
	        "InstanceRootVolumeType": "'$InstanceRootVolumeType'",
	        "InstanceType": "'$InstanceType'",
	        "InstanceUserData": "'$InstanceUserData'"
	}
}'


function CreateRFC() {
echo "inside the createRFC function" 
 RfcInput=$1
  RfcParams=$2
  _RfcOutput=$3

  # Set RFC requested start & end time
  start_time=`date --date='1 minutes' --utc +%FT%TZ`
  end_time=`date --date='1 days' --utc +%FT%TZ`
  RfcInput="${RfcInput/START_TIME/$start_time}"
  RfcInput="${RfcInput/END_TIME/$end_time}"



  # Create RFC
  Output=`aws amscm create-rfc --cli-input-json "$RfcInput" --execution-parameters "$RfcParams" --region us-east-1`
  if [ -z "$Output" ]; then
    echo 'RFC failed to create'
    exit 1
  fi
  echo 'create-rfc Output ' $Output
  RfcId=$( echo $Output | jq '.RfcId' )
  RfcId=`echo "$RfcId" | sed 's/"//g'`
  echo 'Created RFC: ' $RfcId

  #Submit RFC
  Submit=`aws amscm submit-rfc --rfc-id $RfcId --region us-east-1`
  echo 'submit-rfc Output ' $Submit

  #Wait until RFC is completed
  RfcStatus=''
  count=1
  while [ "$RfcStatus" != "Success" ] && [ "$RfcStatus" != "Failure" ] && [ "$RfcStatus" != "Canceled" ] && [ "$RfcStatus" != "Rejected" ]; do
    sleep 10
    Rfc=`aws amscm get-rfc --rfc-id $RfcId --output json --region us-east-1`
	#echo 'rfc: ' $Rfc
    RfcStatus=`echo $Rfc | jq '.Rfc.Status.Id' | sed 's/"//g'`
    echo 'RfcStatus: ' $RfcStatus
	((count++))
  if [ $count -eq 360 ]
    then
       printf "time for a break,count has a value of $count\n"
       break
  fi     
  done

  # Set _RfcOutput variable and return
  if [ "$RfcStatus" != "Success" ]; then
    echo 'RFC failed to execute'
    exit 1
  fi
}

# 1 - Create Access Stack
StackRfcOutput=""
CreateRFC "$StackRFC" "$StackParams" StackRfcOutput
