<%@ page contentType="text/plain; charset=UTF-8" pageEncoding="UTF-8" session="false" %>
SRE Java Middleware Lab
Servidor: <%= application.getServerInfo() %>
Status: OK
Data UTC: <%= java.time.Instant.now().toString() %>
