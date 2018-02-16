#!/bin/bash
StackID=$1
VpcID="vpc-8bbd82ec"
UserID=$2

#RUN_ID=` date +%s | sha256sum | base64 | head -c 6 | awk '{print tolower($0)}'`
#echo "starting run ID: $RUN_ID"
#test
StackRFC='{
  "ChangeTypeId": "ct-1dmlg9g1l91h6",
  "ChangeTypeVersion": "1.0",
  "Description": "Stack Admin Access for '$UserID'",
  "ExpectedOutcome": "Stack Admin Accessfor '$UserID'",
  "ImplementationPlan": "Automated Provisioning",
  "RollbackPlan": "Manual rollback",
  "Title": "Stack Admin Access for '$UserID'",
  "WorstCaseScenario": "RFC fails",
  "RequestedStartTime": "START_TIME",
  "RequestedEndTime": "END_TIME"
}'

StackParams='{
        "DomainFQDN":"SCOTIA.SGNGROUP.NET",
        "StackIds": ["'$StackID'"],
        "VpcId": "'$VpcID'",
        "Username": "'$UserID'",
        "TimeRequestedInHours": 8
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


StackRfcOutput=""
CreateRFC "$StackRFC" "$StackParams" StackRfcOutput
