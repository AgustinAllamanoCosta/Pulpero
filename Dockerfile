FROM nickblah/lua:5.2.4-luarocks-ubuntu

WORKDIR /lua

COPY lua/pulpero/core pulpero/core
COPY lua/pulpero/load_dep.lua pulpero/load_dep.lua

RUN apt-get update
RUN apt-get install -y build-essential
RUN apt install -y cmake
RUN luarocks install luv

EXPOSE 8080
CMD ["lua","-e", "require('./pulpero/load_dep')", "./pulpero/core/init.lua"]
