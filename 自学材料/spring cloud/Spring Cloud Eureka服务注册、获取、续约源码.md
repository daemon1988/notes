# Spring Cloud Eureka服务注册、获取、续约源码

## 一、客户端：

1、jar包：com.netflix.eureka    eureka-client-1.9.8.jar

2、类名：com.netflix.discovery.DiscoveryClient.java

3、eureka客户端核心代码，注册和续约都是以REST请求的方式

```java
private void initScheduledTasks() {    
    //
    if (clientConfig.shouldFetchRegistry()) {        
        // registry cache refresh timer        
        int registryFetchIntervalSeconds = clientConfig.getRegistryFetchIntervalSeconds();        
        int expBackOffBound = clientConfig.getCacheRefreshExecutorExponentialBackOffBound(); 
        // 启动CacheRefreshThread线程定时完成服务获取，默认时间间隔为30秒
        scheduler.schedule(                
            new TimedSupervisorTask(                        
                "cacheRefresh",                        
                scheduler,                        
                cacheRefreshExecutor,                        
                registryFetchIntervalSeconds,
                TimeUnit.SECONDS,                        
                expBackOffBound,                        
                new CacheRefreshThread()                
            ),                
            registryFetchIntervalSeconds, TimeUnit.SECONDS);    
    }    
    if (clientConfig.shouldRegisterWithEureka()) {        
        int renewalIntervalInSecs = instanceInfo.getLeaseInfo().getRenewalIntervalInSecs();        
        int expBackOffBound = clientConfig.getHeartbeatExecutorExponentialBackOffBound();   
        logger.info("Starting heartbeat executor: " + "renew interval is: {}", renewalIntervalInSecs);        
        // Heartbeat timer 
        // 通过HeartbeatThread线程定时完成服务续约
        // 默认续约的时间间隔为30秒，默认的服务信息保留时间为90秒
        scheduler.schedule(                
            new TimedSupervisorTask(                        
                "heartbeat",                        
                scheduler,                        
                heartbeatExecutor,                        
                renewalIntervalInSecs,  //续约间隔时间                      
                TimeUnit.SECONDS,                        
                expBackOffBound,        //服务信息保留时间                
                new HeartbeatThread()                
            ),                
            renewalIntervalInSecs, TimeUnit.SECONDS);        
        // InstanceInfo replicator        
        instanceInfoReplicator = new InstanceInfoReplicator(                
            this,                
            instanceInfo,
            clientConfig.getInstanceInfoReplicationIntervalSeconds(),  
            2); // burstSize        
        statusChangeListener = new ApplicationInfoManager.StatusChangeListener() {           
            @Override            
            public String getId() {               
                return "statusChangeListener";            
            }            
            @Override           
            public void notify(StatusChangeEvent statusChangeEvent) { 
                if (InstanceStatus.DOWN == statusChangeEvent.getStatus() || 
                    InstanceStatus.DOWN == statusChangeEvent.getPreviousStatus()) { 
                    // log at warn level if DOWN was involved   
                    logger.warn("Saw local status change event {}", 
                                statusChangeEvent);                
                } else {                    
                    logger.info("Saw local status change event {}", 
                                statusChangeEvent);                
                }                
                instanceInfoReplicator.onDemandUpdate();           
            }       
        };       
        if (clientConfig.shouldOnDemandUpdateStatusChange()) {   
           applicationInfoManager.registerStatusChangeListener(statusChangeListener);         }        
       //服务注册的定时任务
        instanceInfoReplicator.start(clientConfig.getInitialInstanceInfoReplicationIntervalSeconds());    
    } else {        
        logger.info("Not registering with Eureka server per configuration");    
    }
}
```

4、客户端服务注册（源于instanceInfoReplicator.start()的run方法）

InstanceInfoReplicator实现了Runnable接口

```java
public void run() {    
    try {        
        discoveryClient.refreshInstanceInfo();       
        Long dirtyTimestamp = instanceInfo.isDirtyWithTime();  
        if (dirtyTimestamp != null) {           
            discoveryClient.register(); //真正的注册 
            instanceInfo.unsetIsDirty(dirtyTimestamp);    
        }   
    } catch (Throwable t) {       
        logger.warn("There was a problem with the instance info replicator", t);   
    } finally {       
        Future next = scheduler.schedule(this, replicationIntervalSeconds, TimeUnit.SECONDS);        
        scheduledPeriodicRef.set(next);   
    }
}
```

## 二、服务端：

1、jar包：com.netflix.eureka  eureka-core

2、类名称：com.netflix.eureka.resources.ApplicationResource

3、服务端服务注册中心处理：

```java
@POST
@Consumes({"application/json", "application/xml"})
public Response addInstance(InstanceInfo info, 
                            @HeaderParam(PeerEurekaNode.HEADER_REPLICATION) 
                            String isReplication) { 
    logger.debug("Registering instance {} (replication={})", info.getId(), isReplication);    
    // validate that the instanceinfo contains all the necessary required fields    
    if (isBlank(info.getId())) {        
        return Response.status(400).entity("Missing instanceId").build();
    } else if (isBlank(info.getHostName())) {        
        return Response.status(400).entity("Missing hostname").build();   
    } else if (isBlank(info.getIPAddr())) {        
        return Response.status(400).entity("Missing ip address").build(); 
    } else if (isBlank(info.getAppName())) {       
        return Response.status(400).entity("Missing appName").build();    
    } else if (!appName.equals(info.getAppName())) {        
        return Response.status(400).entity("Mismatched appName, expecting " + appName + " but was " + info.getAppName()).build();   
    } else if (info.getDataCenterInfo() == null) {       
        return Response.status(400).entity("Missing dataCenterInfo").build();    
    } else if (info.getDataCenterInfo().getName() == null) {       
        return Response.status(400).entity("Missing dataCenterInfo Name").build();    
    }    
    // handle cases where clients may be registering with bad DataCenterInfo with missing data    
    enterInfoId = ((UniqueIdentifier) dataCenterInfo).getId();        
    if (isBlank(dataCenterInfoId)) {           
        boolean experimental = "true".equalsIgnoreCase(serverConfig.getExperimental("registration.validation.dataCenterInfoId"));            
        if (experimental) {               
            String entity = "DataCenterInfo of type " + dataCenterInfo.getClass() + " must contain a valid id";
            return Response.status(400).entity(entity).build();            
        } else if (dataCenterInfo instanceof AmazonInfo) {    
            AmazonInfo amazonInfo = (AmazonInfo) dataCenterInfo;
            String effectiveId = amazonInfo.get(AmazonInfo.MetaDataKey.instanceId);               
            if (effectiveId == null) {                    amazonInfo.getMetadata().put(AmazonInfo.MetaDataKey.instanceId.getName(), info.getId());                
            }           
        } else {                
            logger.warn("Registering DataCenterInfo of type {} without an appropriate id", dataCenterInfo.getClass());            
        }        
    }    
}    
registry.register(info, "true".equals(isReplication));    
return Response.status(204).build();  // 204 to be backwards compatible}
```

