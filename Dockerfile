FROM amazoncorretto:21-alpine
RUN addgroup -S mcgroup && adduser -S mcuser -G mcgroup
RUN mkdir -p /app/bin /app/data && chown -R mcuser:mcgroup /app
WORKDIR /app/bin
RUN wget -O paper.jar https://api.papermc.io/v2/projects/paper/versions/1.21.1/builds/131/downloads/paper-1.21.1-131.jar
USER mcuser
WORKDIR /app/data
EXPOSE 25565
CMD echo "eula=true" > eula.txt && java -Xms2048M -Xmx2048M -jar /app/bin/paper.jar nogui