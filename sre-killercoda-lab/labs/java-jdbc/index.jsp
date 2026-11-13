<%@ page contentType="text/plain; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ page import="java.sql.Connection,java.sql.DriverManager,java.sql.PreparedStatement,java.sql.ResultSet,java.sql.SQLException" %>
<%
/*
 * Aula SRE: WAR real, Tomcat e JDBC PostgreSQL, somente SELECT.
 * NÃO registrar senhas, connection strings com credenciais ou stack traces.
 */
response.setHeader("Cache-Control", "no-store");
String host = System.getenv("PGHOST");
String database = System.getenv("PGDATABASE");
String username = System.getenv("PGUSER");
String password = System.getenv("PGPASSWORD");
if (host == null || database == null || username == null || password == null) {
    response.setStatus(503);
    out.println("SRE Java JDBC Lab");
    out.println("Status: ERROR");
    out.println("Motivo: variavel de ambiente de banco ausente");
    return;
}
String jdbcUrl = "jdbc:postgresql://" + host + ":5432/" + database
    + "?connectTimeout=3&socketTimeout=5&ApplicationName=sre-java-jdbc-lab";
try {
    Class.forName("org.postgresql.Driver");
    try (Connection connection = DriverManager.getConnection(jdbcUrl, username, password);
         PreparedStatement statement = connection.prepareStatement(
             "SELECT current_database(), current_user, count(*) FROM incidents")) {
        statement.setQueryTimeout(5);
        statement.setReadOnly(true);
        try (ResultSet result = statement.executeQuery()) {
            if (!result.next()) {
                response.setStatus(503);
                out.println("SRE Java JDBC Lab");
                out.println("Status: ERROR - nenhuma linha retornada");
                return;
            }
            out.println("SRE Java JDBC Lab");
            out.println("Servidor Java: " + application.getServerInfo());
            out.println("JDBC: PostgreSQL");
            out.println("Database: " + result.getString(1));
            out.println("Usuario SQL: " + result.getString(2));
            out.println("Incidentes: " + result.getLong(3));
            out.println("Status: OK");
        }
    }
} catch (ClassNotFoundException error) {
    response.setStatus(503);
    out.println("SRE Java JDBC Lab");
    out.println("Status: ERROR - driver JDBC indisponivel");
} catch (SQLException error) {
    response.setStatus(503);
    out.println("SRE Java JDBC Lab");
    out.println("Status: ERROR - consulta JDBC falhou");
    out.println("SQLSTATE: " + (error.getSQLState() == null ? "desconhecido" : error.getSQLState()));
}
%>
