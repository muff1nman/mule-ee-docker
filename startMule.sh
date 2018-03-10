#!/bin/bash
# Custom mule start up scrip that will register run time to anypoint platform

### Mule Startup Script argument  Required  Description ###
## Platform relate argument		              if any require argument below not exist, runtime will not register to runtime ##
# orgId                           yes	      orgId that runtime will register to
# username	                      yes	      Platform username
# password	                      yes	      Platform password
# envName	                        yes	      Environment Name that runtime will register to
# anypointPlatformHost	          no	      Default anypoint.mulesoft.com
# anypointPlatformPort	          no	      Default 443
# registerTargetGroupName	        no	      Group name that runtime will join. Default runtime will not join any group
# registerTargetGroupType	        no	      Group type serverGroup or cluster. Default runtime will not join any group
# proxyHost	                      no	      proxy for CURL command
# proxyPort	                      no        proxy for CURL command
# proxyUsername	                  no	      proxy for CURL command
# proxyPassword	                  no	      proxy for CURL command
## Mule runtime relate argument ##		
# client_id	                      no	      value for -M-Danypoint.platform.client_id
# client_secret	                  no	      value for -M-Danypoint.platform.client_secret
# key                           	no	      value for -M-Dkey
# env	                            no	      value for -M-Denv=$env
# initMemory	                    no	      value for -M-Dwrapper.java.initmemory. Default 512
# maxMemory	                      no	      value for -M-Dwrapper.java.maxmemory. Default 512
# startMuleOtherArguments	        no	      Other key value argument that will pass to runtime

echo "start script with variable.."
echo "orgId: $orgId"
echo "username: $username"
if [ "$password" != "" ]
    then
        echo "password: *******"
fi
echo "envName: $envName"
echo "anypointPlatformHost: $anypointPlatformHost"
echo "anypointPlatformPort: $anypointPlatformPort"
echo "registerTargetGroupName: $registerTargetGroupName"
echo "registerTargetGroupType: $registerTargetGroupType"
echo "client_id: $client_id"
if [ "$client_secret" != "" ]
    then
        echo "client_secret: *******"
fi
if [ "$key" != "" ]
    then
        echo "key: *******"
fi
echo "env - $env"
echo "initMemory: $initMemory"
echo "maxMemory: $maxMemory"
echo "proxyHost: $proxyHost"
echo "proxyPort: $proxyPort"
echo "proxyUsername: $proxyUsername"
if [ "$proxyPassword" != "" ]
    then
        echo "proxyPassword: *******"
fi
echo "maxMemory: $maxMemory"
echo "startMuleOtherArguments: $startMuleOtherArguments"

#Function to wait server to start up
waitingServerStart()
{
  # Waiting server to start up
  while [ "$serverStatus" != "RUNNING" ] 
  do
    sleep 15s
    # Get Server Status from AMC
    echo "Getting server status from $hybridAPI/servers..."
    serverData=$(curl $proxyOption -s $hybridAPI/servers/ -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken")

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
  serverData=$(curl $proxyOption -s $hybridAPI/servers/ -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken")
  
  jqParam=".data[] | select(.name==\"$serverName\").id"
  serverId=$(echo $serverData | /app/jq --raw-output "$jqParam")
  echo "ServerId $serverName: $serverId"

  echo "Getting cluster details from $hybridAPI/clusters..."
  clusterData=$(curl $proxyOption -s $hybridAPI/clusters/ -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken")

  jqParam=".data[] | select(.name==\"$registerTargetGroupName\").id"
  clusterId=$(echo $clusterData | /app/jq --raw-output "$jqParam")
  echo "clusterId $registerTargetGroupName: $clusterId"

  # check if cluster is exist or not
  if [ x != "x$clusterId" ]
    then
      echo "$registerTargetGroupName is found in cluster ID: $clusterId"
      echo "POST $hybridAPI/clusters/$clusterId/servers {\"serverId\":$serverId}"
      addtoClusterResponse=$(curl $proxyOption -s -X "POST" "$hybridAPI/clusters/$clusterId/servers/" -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken" -H "Content-Type: application/json" -d "{\"serverId\":$serverId}")
      echo "$addtoClusterResponse"
      
    else
      echo "$registerTargetGroupName is not found. Create multicase cluster with serverId:$serverId"
      echo "POST $hybridAPI/clusters { \"name\": \"$registerTargetGroupName\", \"multicastEnabled\": true, \"servers\": [{\"serverId\": $serverId}]}"
      addtoClusterResponse=$(curl $proxyOption -s -X "POST" "$hybridAPI/clusters/" -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken" -H "Content-Type: application/json" -d "{ \"name\": \"$clusterName\", \"multicastEnabled\": true, \"servers\": [{\"serverId\": $serverId}]}")
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
  serverData=$(curl $proxyOption -s $hybridAPI/servers/ -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken")
  
  jqParam=".data[] | select(.name==\"$serverName\").id"
  serverId=$(echo $serverData | /app/jq --raw-output "$jqParam")
  echo "ServerId $serverName: $serverId"

  echo "Getting servergroups details from $hybridAPI/serverGroups..."
  serverGroupData=$(curl $proxyOption -s $hybridAPI/serverGroups/ -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken")

  jqParam=".data[] | select(.name==\"$registerTargetGroupName\").id"
  serverGroupId=$(echo $serverGroupData | /app/jq --raw-output "$jqParam")
  echo "serverGroupId $registerTargetGroupName: $serverGroupId"

  # check if serverGroup is exist or not
  if [ x != "x$serverGroupId" ]
    then
      echo "$registerTargetGroupName is found in serverGroup ID: $serverGroupId"
      echo "POST $hybridAPI/serverGroups/$serverGroupId/servers/$serverId"
      addtoServerGroupResponse=$(curl $proxyOption -s -X "POST" "$hybridAPI/serverGroups/$serverGroupId/servers/$serverId" -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken")
      echo "$addtoServerGroupResponse"
      
    else
      echo "$registerTargetGroupName is not found. Create serverGroup with serverId:$serverId"
      echo "POST $hybridAPI/serverGroups { \"name\": \"$registerTargetGroupName\", \"serverIds\": [$serverId]}"
      addtoServerGroupResponse=$(curl $proxyOption -s -X "POST" "$hybridAPI/serverGroups" -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken" -H "Content-Type: application/json" -d "{ \"name\": \"$registerTargetGroupName\", \"serverIds\": [$serverId]}")
      echo "$addtoServerGroupResponse"
  fi

  return 0
}

# Main start here
# Check platform parameter if missing change to standalone mode (no server registration/add to group/cluster)
if [[ "$orgId" != "" &&  "$username" != "" &&  "$password" != "" &&  "$envName" != "" ]]
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

        # Check if proxy will be use
        if [[ "$proxyHost" != "" &&  "$proxyPort" != "" ]]
          then
            if [[ "$proxyUsername" != "" &&  "$proxyPassword" != "" ]]
              then
                proxyOption="-x http://$proxyHost:$proxyPort --proxy-user $proxyUsername:$proxyPassword"
              else
                proxyOption="-x http://$proxyHost:$proxyPort"
            fi
        fi
        echo "Proxy option is $proxyOption"
        
        # Authenticate with user credentials (Note the APIs will NOT authorize for tokens received from the OAuth call. A user credentials is essential)
        echo "Getting access token from $accAPI/login..."
        accessToken=$(curl $proxyOption -s $accAPI/login -X POST -d "username=$username&password=$password" | /app/jq --raw-output .access_token)
        echo "Access Token: $accessToken"
    
        ### comment out below session as orgId has been provide as parameter ###
        # Pull org id from my profile info
        #echo "Getting org ID from $accAPI/api/me..."
        #jqParam=".user.contributorOfOrganizations[] | select(.name==\"$orgName\").id"
        #orgId=$(curl $proxyOption -s $accAPI/api/me -H "Authorization:Bearer $accessToken" | /app/jq --raw-output "$jqParam")
        #echo "Organization ID: $orgId"
        
        # Pull env id from matching env name
        echo "Getting env ID from $accAPI/api/organizations/$orgId/environments..."
        jqParam=".data[] | select(.name==\"$envName\").id"
        envId=$(curl $proxyOption -s $accAPI/api/organizations/$orgId/environments -H "Authorization:Bearer $accessToken" | /app/jq --raw-output "$jqParam")
        echo "Environment ID: $envId"
        
        # Request amc token
        echo "Getting registrion token from $hybridAPI/servers/registrationToken..."
        amcToken=$(curl $proxyOption -s $hybridAPI/servers/registrationToken -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken" | /app/jq --raw-output .data)
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
./mule -M-Dwrapper.java.initmemory=$initMemory -M-Dwrapper.java.maxmemory=$maxMemory -M-Danypoint.platform.client_id=$client_id -M-Danypoint.platform.client_secret=$client_secret -M-Dkey=$key -M-Denv=$env $startMuleOtherArguments



