#!/bin/bash
# Custom mule start up scrip that will register run time to anypoint platform

#hardcode environment variable for testing
businessGroupName="ExxonMobil"
username="tanetgFeb2018"
password="tanetgFeb2018"
environmentName="Production"
anypointPlatformHost="anypoint.mulesoft.com"
anypointPlatformPort=443
registerTargetName="HelloDocker"
registerTargetType="cluster"
client_id="b957b304bcb04da59d4d565c0b4d433b"
client_secret="c5Fa13E33E4C4eDd847CB1eE184180E2"
key="testbyseng"
env="prd"

# end hardcode

echo "username - $username"
echo "orgName - $orgName"
echo "envName - $envName"
echo "platformurl - $platformurl"
echo "clusterName - $clusterName"
echo "client_id - $client_id"
echo "client_secret - $client_secret"
echo "key - $key"
echo "env - $env"
echo "standalone - $standalone"

# Parameter check and set default value
# check platform parameter if missing change to standalone mode (no server registration/add to group/cluster)
if [ "$orgName" == "" ||  "$username" == "" ||  "$password" == "" ||  "$username" == "" ||  ]
    then
      echo "$addtoClusterResponse"
    else  
      echo "$addtoClusterResponse"
fi
 
hybridAPI=https://$platformurl:$httpPort/hybrid/api/v1
accAPI=https://$platformurl:$httpPort/accounts
 
serverName=`cat /etc/hostname`
echo "Server name is $serverName"
 

 #Function to register mule to cluster
registerMuleContainerToCluster()
{
  # register Mule to cluster
  echo "sleeping for 180 seconds"
  sleep 180s
  echo "Done sleeping and hope that mule runtime already start up"
  
  echo "Adding server to cluster"
  echo "Getting server details from $hybridAPI/servers..."
  serverData=$(curl -s $hybridAPI/servers/ -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken")
  
  jqParam=".data[] | select(.name==\"$serverName\").id"
  serverId=$(echo $serverData | /app/jq --raw-output "$jqParam")
  echo "ServerId $serverName: $serverId"

  echo "Getting cluster details from $hybridAPI/clusters..."
  clusterData=$(curl -s $hybridAPI/clusters/ -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken")

  jqParam=".data[] | select(.name==\"$clusterName\").id"
  clusterId=$(echo $clusterData | /app/jq --raw-output "$jqParam")
  echo "clusterId $clusterName: $clusterId"

  # check if cluster is exist or not
  if [ x != "x$clusterId" ]
    then
      echo "$clusterName is found in cluster ID: $clusterId"
      echo "POST $hybridAPI/clusters/$clusterId/servers {\"serverId\":$serverId}"
      addtoClusterResponse=$(curl -s -X "POST" "$hybridAPI/clusters/$clusterId/servers/" -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken" -H "Content-Type: application/json" -d "{\"serverId\":$serverId}")
      echo "$addtoClusterResponse"
      
    else
      echo "$clusterName is not found. Create multicase cluster with serverId:$serverId"
      echo "POST $hybridAPI/clusters { \"name\": \"$clusterName\", \"multicastEnabled\": true, \"servers\": [{\"serverId\": $serverId}]}"
      addtoClusterResponse=$(curl -s -X "POST" "$hybridAPI/clusters/" -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken" -H "Content-Type: application/json" -d "{ \"name\": \"$clusterName\", \"multicastEnabled\": true, \"servers\": [{\"serverId\": $serverId}]}")
      echo "$addtoClusterResponse"
  fi

  return 0
}

if [ $standalone != "true" ]
  then
    # Authenticate with user credentials (Note the APIs will NOT authorize for tokens received from the OAuth call. A user credentials is essential)
    echo "Getting access token from $accAPI/login..."
    accessToken=$(curl -s $accAPI/login -X POST -d "username=$username&password=$password" | /app/jq --raw-output .access_token)
    echo "Access Token: $accessToken"
    
    # Pull org id from my profile info
    echo "Getting org ID from $accAPI/api/me..."
    jqParam=".user.contributorOfOrganizations[] | select(.name==\"$orgName\").id"
    orgId=$(curl -s $accAPI/api/me -H "Authorization:Bearer $accessToken" | /app/jq --raw-output "$jqParam")
    echo "Organization ID: $orgId"
    
    # Pull env id from matching env name
    echo "Getting env ID from $accAPI/api/organizations/$orgId/environments..."
    jqParam=".data[] | select(.name==\"$envName\").id"
    envId=$(curl -s $accAPI/api/organizations/$orgId/environments -H "Authorization:Bearer $accessToken" | /app/jq --raw-output "$jqParam")
    echo "Environment ID: $envId"
    
    # Request amc token
    echo "Getting registrion token from $hybridAPI/servers/registrationToken..."
    amcToken=$(curl -s $hybridAPI/servers/registrationToken -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken" | /app/jq --raw-output .data)
    echo "AMC Token: $amcToken"
    
    # Register new mule
    echo "Registering $serverName to Anypoint Platform..."
    ./amc_setup -H $amcToken $serverName

    echo "Calling the add server to cluster ARM function"
    registerMuleContainerToCluster &
  else
    echo "start mule in standalone mode"
fi


 
echo "Starting Mule"
 
# Start mule!
./mule -M-Danypoint.platform.client_id=$client_id -M-Danypoint.platform.client_secret=$client_secret -M-Dkey=$key -M-Denv=$env

# De-register
echo "De-registering $serverName from Anypoint Platform..."
# Get Server ID from AMC
echo "Getting server details from $hybridAPI/servers..."
serverData=$(curl -s $hybridAPI/servers/ -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken")

jqParam=".data[] | select(.name==\"$serverName\").id"
serverId=$(echo $serverData | /app/jq --raw-output "$jqParam")
echo "ServerId $serverName: $serverId"

jqParam=".data[] | select(.name==\"$serverName\").clusterId"
clusterId=$(echo $serverData | /app/jq --raw-output "$jqParam")

if [ "$clusterId" != "null" ]
  then
    echo "$serverName is found in cluster ID: $clusterId"

    # Removing mule server from the cluster
    echo "Removing server from cluster at $hybridAPI/clusters/$clusterId/servers/$serverId..."
    rmResponse=$(curl -s -X "DELETE" "$hybridAPI/clusters/$clusterId/servers/$serverId" -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken")

    # If error response from removing last one mule server from the cluster
    if [ "$rmResponse" != "" ]
      then
        echo "Looks like $serverName is the last server in the cluster."
        echo "Removing cluster at $hybridAPI/clusters/$clusterId..."
        curl -s -X "DELETE" "$hybridAPI/clusters/$clusterId" -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken"
    fi

fi

# Deregister mule from ARM
echo "Deregistering Server at $hybridAPI/servers/$serverId..."
curl -s -X "DELETE" "$hybridAPI/servers/$serverId" -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken"

echo "Everything looks clean now."
echo "Live long and prosper."