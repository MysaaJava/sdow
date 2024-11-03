FROM python:3.12-bookworm

RUN apt update
RUN apt upgrade -y
RUN apt install -y git pv sqlite3 default-mysql-client
RUN pip install tqdm

RUN mkdir /sdow/
WORKDIR /sdow/

ADD ./makeDb.sh /sdow/makeDb.sh

ENTRYPOINT bash makeDb.sh
