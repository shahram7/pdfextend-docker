# PDFExtend-docker

This repository is a Dockerized build wrapper for the original PDFExtend project by @DorianRudolph.
Original project: https://github.com/DorianRudolph/pdfextend

The goal of this repository is to automatically build and publish a Docker image on Docker Hub so PDFExtend can be self-hosted and accessed easily via a web server.

## Docker-CLI
```
docker run -d \
  -p 1080:80 \
  --name pdfextend \
  shahram7/pdfextend:latest
```

## Docker-Compose
```
services:
    pdfextend:
        ports:
            - 1080:80
        container_name: pdfextend
        image: shahram7/pdfextend:latest
```

## Credits
All credit for PDFExtend goes to **@DorianRudolph**.  
This repository only provides a Docker image and CI/CD automation for convenient deployment.
