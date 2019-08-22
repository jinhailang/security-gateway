# Security-gateway

安全网关的主要目的是降低客户接入多个安全服务的成本，经过简单配置，通过安全网关将 http 请求自动代理到后端单个或多个安全服务。

**安全网关核心模块包括请求（支持 uri, host 等多种头字段）路由，插件管理以及子系统（负载，健康检查等）管理。**

详见 [开发文档](xxx)

## Depend

- openresty/1.15.8.1
- etcd (v2 api)


## Start

```
openresty -c /opt/gateway/conf/nginx_dev.conf
```

## Acknowledgments

inspired by `Apisix` and `Kong`.



## end
