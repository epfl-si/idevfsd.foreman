CREATE ROLE foreman LOGIN NOCREATEDB NOCREATEROLE;
CREATE DATABASE foreman;
GRANT ALL PRIVILEGES ON foreman TO foreman;

