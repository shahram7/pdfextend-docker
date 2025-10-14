# PDFExtend-docker

PDFExtend is a simple tool developed by @DorianRudolph that adds margins to PDF files, giving you extra space to write or draw notes when using PDF annotation apps.

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
