CREATE DATABASE compreface;
CREATE USER compreface WITH ENCRYPTED PASSWORD 'SuaSenhaForteDB';
GRANT ALL PRIVILEGES ON DATABASE compreface TO compreface;
\c compreface
GRANT ALL ON SCHEMA public TO compreface;