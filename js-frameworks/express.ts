import express from 'express'

const app = express()

app.use(express.json());
app.use((req, res, next) => {
    console.log("<--", req.method, req.url);
    next();
    console.log("-->", req.method, req.url);
});

app.get('/', (req, res) => {
    res.send('Hello World')
})


app.get(
    '/json',
    async (req, res) => {
        res.statusCode = 200;
        res.send({
            message: "Hello World"
        })
    },
)

app.post('/id/:id', (req, res) => {
    res.status(201).send(req.params.id)
})

app.listen(3000)