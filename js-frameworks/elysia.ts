import { Elysia } from 'elysia'

const app = new Elysia()
	.get('/heyo', "Hello World")

export default app;