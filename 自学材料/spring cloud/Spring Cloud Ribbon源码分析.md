# Spring Cloud Ribbon源码分析

1、Ribbon是通过RestTemplate实现客户端的负载均衡，代码如下：

```java
@Bean
@LoadBalanced
public RestTemplate restTemplate(){   
    return new RestTemplate();
}
```

2、@LoadBalanced注解用来给RestTemplate做标记，以使用负载均衡的客户端（LoadBalancerClient）来配置它。

```java
/** 
 * Annotation to mark a RestTemplate bean to be configured to use a LoadBalancerClient. 
 * @author Spencer Gibb 
 */
 @Target({ ElementType.FIELD, ElementType.PARAMETER, ElementType.METHOD })
 @Retention(RetentionPolicy.RUNTIME)
 @Documented
 @Inherited
 @Qualifier
 public @interface LoadBalanced {}
```

3、LoadBalancerClient

```java
/**
 * Represents a client-side load balancer.
 *
 * @author Spencer Gibb
 */
public interface LoadBalancerClient extends ServiceInstanceChooser {
    <T> T execute(String serviceId, LoadBalancerRequest<T> request) throws IOException;
    
    ServiceInstance choose(String serviceId);//ServiceInstanceChooser的方法
    
    URI reconstructURI(ServiceInstance instance, URI original);
}
```

execute():使用指定服务的LoadBalancer中的ServiceInstance执行请求。

choose():为指定的服务从LoadBalancer中选择ServiceInstance。

reconstructURI():创建一个适当的URI，该URI具有供系统使用的实际主机和端口。一些系统使用逻辑服务名作为主机的URI（替代服务实例的host:port形式）进行请求，例如http://myservice/path/to/service。

3、LoadBalancerAutoConfiguration作为实现客户端负载均衡器的自动化配置类。

​		实现负载均衡自动化配置需要满足两个条件：

​		（1）@ConditionalOnClass(RestTemplate.class) RestTemplate类必须存在于当前工程的环境中

​		（2）@ConditionalOnBean(LoadBalancerClient.class) Spring的Bean工程中必须有LoadBalancerClient的实现Bean。

​		主要完成的工作：

​		（1）维护一个被@LoadBalanced注解修饰的RestTemplate对象列表，并初始化->通过RestTemplateCustomizer对象给需要客户端负载均衡的RestTemplate增加LoadBalancerInterceptor拦截器

​		（2）自动重试机制需要当前工程的环境中存在RetryTemplate类

```java
@Configuration
@ConditionalOnClass(RestTemplate.class)
@ConditionalOnBean(LoadBalancerClient.class)
@EnableConfigurationProperties(LoadBalancerRetryProperties.class)
public class LoadBalancerAutoConfiguration {

	@LoadBalanced
	@Autowired(required = false)
	private List<RestTemplate> restTemplates = Collections.emptyList();

	@Autowired(required = false)
	private List<LoadBalancerRequestTransformer> transformers = Collections.emptyList();

	@Bean
	public SmartInitializingSingleton loadBalancedRestTemplateInitializerDeprecated(
			final ObjectProvider<List<RestTemplateCustomizer>> restTemplateCustomizers) {
		return () -> restTemplateCustomizers.ifAvailable(customizers -> {
			for (RestTemplate restTemplate : LoadBalancerAutoConfiguration.this.restTemplates) {
				for (RestTemplateCustomizer customizer : customizers) {
					customizer.customize(restTemplate);
				}
			}
		});
	}

	@Bean
	@ConditionalOnMissingBean //仅当指定的类不在类路径上时才匹配
	public LoadBalancerRequestFactory loadBalancerRequestFactory(
			LoadBalancerClient loadBalancerClient) {
		return new LoadBalancerRequestFactory(loadBalancerClient, this.transformers);
	}

	@Configuration
	@ConditionalOnMissingClass("org.springframework.retry.support.RetryTemplate")
	static class LoadBalancerInterceptorConfig {

		@Bean
		public LoadBalancerInterceptor ribbonInterceptor(
				LoadBalancerClient loadBalancerClient,
				LoadBalancerRequestFactory requestFactory) {
			return new LoadBalancerInterceptor(loadBalancerClient, requestFactory);
		}

		@Bean
		@ConditionalOnMissingBean
		public RestTemplateCustomizer restTemplateCustomizer(
				final LoadBalancerInterceptor loadBalancerInterceptor) {
			return restTemplate -> {
				List<ClientHttpRequestInterceptor> list = new ArrayList<>(
						restTemplate.getInterceptors());
				list.add(loadBalancerInterceptor);
				restTemplate.setInterceptors(list);
			};
		}

	}

	/**
	 * Auto configuration for retry mechanism.
	 * 自动配置重试机制
	 */
	@Configuration
	@ConditionalOnClass(RetryTemplate.class)
	public static class RetryAutoConfiguration {

		@Bean
		@ConditionalOnMissingBean
		public LoadBalancedRetryFactory loadBalancedRetryFactory() {
			return new LoadBalancedRetryFactory() {
			};
		}

	}

	/**
	 * Auto configuration for retry intercepting mechanism.
	 * 自动配置重试拦截机制
	 */
	@Configuration
	@ConditionalOnClass(RetryTemplate.class)
	public static class RetryInterceptorAutoConfiguration {

		@Bean
		@ConditionalOnMissingBean
		public RetryLoadBalancerInterceptor ribbonInterceptor(
				LoadBalancerClient loadBalancerClient,
				LoadBalancerRetryProperties properties,
				LoadBalancerRequestFactory requestFactory,
				LoadBalancedRetryFactory loadBalancedRetryFactory) {
			return new RetryLoadBalancerInterceptor(loadBalancerClient, properties,
					requestFactory, loadBalancedRetryFactory);
		}

		@Bean
		@ConditionalOnMissingBean
		public RestTemplateCustomizer restTemplateCustomizer(
				final RetryLoadBalancerInterceptor loadBalancerInterceptor) {
			return restTemplate -> {
				List<ClientHttpRequestInterceptor> list = new ArrayList<>(
						restTemplate.getInterceptors());
				list.add(loadBalancerInterceptor);
				restTemplate.setInterceptors(list);
			};
		}

	}

}
```