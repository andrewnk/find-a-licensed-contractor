FROM node:lts-alpine

COPY . /home/node

WORKDIR /home/node

RUN npm i

CMD ["npm", "run", "serve"]