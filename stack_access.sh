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
  RfcInput=$1
  RfcParams=$2
  _RfcOutput=$3

  # Set RFC requested start & end time
  start_time=`date --date='1 minutes' --utc +%FT%TZ`
  end_time=`date --date='1 days' --utc +%FT%TZ`
  RfcInput="${RfcInput/START_TIME/$start_time}"
  RfcInput="${RfcInput/END_TIME/$end_time}"

  # Create RFC
  Output=`/usr/bin/aws amscm create-rfc --cli-input-json "$RfcInput" --execution-parameters "$RfcParams"`
  if [ -z "$Output" ]; then
    echo 'RFC failed to create'
    exit 1
  fi
  RfcId=`echo "$Output" | sed 's/"//g'`
  echo 'Created RFC: ' $RfcId

  #Submit RFC
  Submit=`/usr/bin/aws amscm submit-rfc --rfc-id $RfcId`

  #Wait until RFC is completed
  RfcStatus=''
  while [ "$RfcStatus" != "Success" ] && [ "$RfcStatus" != "Failure" ] && [ "$RfcStatus" != "Canceled" ] && [ "$RfcStatus" != "Rejected" ]; do
    sleep 10
    Rfc=`aws amscm get-rfc --rfc-id $RfcId --output json`
    RfcStatus=`echo $Rfc | jq '.Rfc.Status.Id' | sed 's/"//g'`
  done

  # Set _RfcOutput variable and return
  if [ "$RfcStatus" != "Success" ]; then
    echo 'RFC failed to execute'
    exit 1
  fi
  eval $_RfcOutput="'$Rfc'"
  return 0
}


# 1 - Create Access Stack
StackRfcOutput=""
CreateRFC "$StackRFC" "$StackParams" StackRfcOutput
