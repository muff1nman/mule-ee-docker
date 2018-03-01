#!/bin/bash
# Custom mule start up scrip that will register run time to anypoint platform

#hardcode environment variable for testing

orgName="ExxonMobil"
username="tanetgFeb2018"
password="tanetgFeb2018"
envName="Production"
#anypointPlatformHost="anypoint.mulesoft.com"
#anypointPlatformPort=443
registerTargetGroupName="HelloServerGroup"
registerTargetGroupType="serverGroup"
client_id="b957b304bcb04da59d4d565c0b4d433b"
client_secret="c5Fa13E33E4C4eDd847CB1eE184180E2"
key="testbyseng"
env="prd"
initMemory=512
maxMemory=512

# end hardcode

echo "start script with variable.."
echo "orgName - $orgName"
echo "username - $username"
echo "envName - $envName"
echo "anypointPlatformHost - $anypointPlatformHost"
echo "anypointPlatformPort - $anypointPlatformPort"
echo "registerTargetGroupName - $registerTargetGroupName"
echo "registerTargetGroupType - $registerTargetGroupType"
echo "client_id - $client_id"
echo "client_secret - $client_secret"
echo "key - $key"
echo "env - $env"
echo "initMemory - $initMemory"
echo "maxMemory - $maxMemory"

#Function to wait server to start up
waitingServerStart()
{
  # Waiting server to start up
  while [ "$serverStatus" != "RUNNING" ] 
  do
    sleep 15s
    # Get Server Status from AMC
    echo "Getting server status from $hybridAPI/servers..."
    serverData=$(curl -s $hybridAPI/servers/ -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken")

    jqParam=".data[] | select(.name==\"$serverName\").status"
    serverStatus=$(echo $serverData | /app/jq --raw-output "$jqParam")
    echo "Server status $serverName: $serverStatus"
  done
}

#Function to add mule to cluster
addMuleToCluster()
{
  waitingServerStart
  echo "Adding server to cluster"
  echo "Getting server details from $hybridAPI/servers..."
  serverData=$(curl -s $hybridAPI/servers/ -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken")
  
  jqParam=".data[] | select(.name==\"$serverName\").id"
  serverId=$(echo $serverData | /app/jq --raw-output "$jqParam")
  echo "ServerId $serverName: $serverId"

  echo "Getting cluster details from $hybridAPI/clusters..."
  clusterData=$(curl -s $hybridAPI/clusters/ -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken")

  jqParam=".data[] | select(.name==\"$registerTargetGroupName\").id"
  clusterId=$(echo $clusterData | /app/jq --raw-output "$jqParam")
  echo "clusterId $registerTargetGroupName: $clusterId"

  # check if cluster is exist or not
  if [ x != "x$clusterId" ]
    then
      echo "$registerTargetGroupName is found in cluster ID: $clusterId"
      echo "POST $hybridAPI/clusters/$clusterId/servers {\"serverId\":$serverId}"
      addtoClusterResponse=$(curl -s -X "POST" "$hybridAPI/clusters/$clusterId/servers/" -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken" -H "Content-Type: application/json" -d "{\"serverId\":$serverId}")
      echo "$addtoClusterResponse"
      
    else
      echo "$registerTargetGroupName is not found. Create multicase cluster with serverId:$serverId"
      echo "POST $hybridAPI/clusters { \"name\": \"$registerTargetGroupName\", \"multicastEnabled\": true, \"servers\": [{\"serverId\": $serverId}]}"
      addtoClusterResponse=$(curl -s -X "POST" "$hybridAPI/clusters/" -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken" -H "Content-Type: application/json" -d "{ \"name\": \"$clusterName\", \"multicastEnabled\": true, \"servers\": [{\"serverId\": $serverId}]}")
      echo "$addtoClusterResponse"
  fi

  return 0
}

#Function to add mule to servergroup
addMuleToServerGroup()
{
  waitingServerStart
  echo "Adding server to serverGroup"
  echo "Getting server details from $hybridAPI/servers..."
  serverData=$(curl -s $hybridAPI/servers/ -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken")
  
  jqParam=".data[] | select(.name==\"$serverName\").id"
  serverId=$(echo $serverData | /app/jq --raw-output "$jqParam")
  echo "ServerId $serverName: $serverId"

  echo "Getting servergroups details from $hybridAPI/serverGroups..."
  serverGroupData=$(curl -s $hybridAPI/serverGroups/ -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken")

  jqParam=".data[] | select(.name==\"$registerTargetGroupName\").id"
  serverGroupId=$(echo $serverGroupData | /app/jq --raw-output "$jqParam")
  echo "serverGroupId $registerTargetGroupName: $serverGroupId"

  # check if serverGroup is exist or not
  if [ x != "x$serverGroupId" ]
    then
      echo "$registerTargetGroupName is found in serverGroup ID: $serverGroupId"
      echo "POST $hybridAPI/serverGroups/$serverGroupId/servers/$serverId"
      addtoServerGroupResponse=$(curl -s -X "POST" "$hybridAPI/serverGroups/$serverGroupId/servers/$serverId" -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken")
      echo "$addtoServerGroupResponse"
      
    else
      echo "$registerTargetGroupName is not found. Create serverGroup with serverId:$serverId"
      echo "POST $hybridAPI/serverGroups { \"name\": \"$registerTargetGroupName\", \"serverIds\": [$serverId]}"
      addtoServerGroupResponse=$(curl -s -X "POST" "$hybridAPI/serverGroups" -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken" -H "Content-Type: application/json" -d "{ \"name\": \"$registerTargetGroupName\", \"serverIds\": [$serverId]}")
      echo "$addtoServerGroupResponse"
  fi

  return 0
}

# Main start here
# Check platform parameter if missing change to standalone mode (no server registration/add to group/cluster)
if [[ "$orgName" != "" &&  "$username" != "" &&  "$password" != "" &&  "$envName" != "" ]]
    then
        echo "Register server to anypoint platform.. and start server"
        if [ "$anypointPlatformHost" == "" ]
            then
                anypointPlatformHost="anypoint.mulesoft.com"
        fi
        if [ "$anypointPlatformPort" == "" ]
            then
                anypointPlatformPort=443
        fi
        serverName=`cat /etc/hostname`
        echo "Server name is $serverName"
        hybridAPI=https://$anypointPlatformHost:$anypointPlatformPort/hybrid/api/v1
        accAPI=https://$anypointPlatformHost:$anypointPlatformPort/accounts
        
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

        if [[ "$registerTargetGroupType" == "cluster" && "$registerTargetGroupName" != "" ]]
            then
                echo "Add server to cluster $registerTargetGroupName"
                addMuleToCluster &
            else
              if [[ "$registerTargetGroupType" == "serverGroup" && "$registerTargetGroupName" != "" ]]
                then
                  echo "Add server to serverGroup $registerTargetGroupName"
                  addMuleToServerGroup &
                else
                  echo "Only register server.."
              fi
        fi
    else
        echo "Not complete platform variable.. start server in standalone mode"  
fi

# Check memory setting
if [ "$initMemory" == "" ]
    then
        initMemory=1024
fi
if [ "$maxMemory" == "" ]
    then
        maxMemory=1024
fi
echo "Starting Mule"
 
# Start mule!
./mule -M-Dwrapper.java.initmemory=$initMemory -M-Dwrapper.java.maxmemory=$maxMemory -M-Danypoint.platform.client_id=$client_id -M-Danypoint.platform.client_secret=$client_secret -M-Dkey=$key -M-Denv=$env



