#!/bin/bash
docker exec elx-mysql mysql -uroot -e 'SELECT 1 AS ok'
echo RC1:$?
docker exec elx-mysql mysql -uroot -e 'CREATE DATABASE IF NOT EXISTS ecto_test'
echo RC2:$?
docker exec elx-mysql mysql -uroot -e 'SHOW DATABASES'
echo RC3:$?
