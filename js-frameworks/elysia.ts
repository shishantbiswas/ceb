import { Elysia } from 'elysia'

const app = new Elysia()
	.get('/heyo', "Hello World")
	.get(
		'/json',
		async (c) => {
			c.status(200);
			return {
				message: "Hello World"
			}
		},
	)
	.post('/id/:id', async (c) => {
		c.status(201);
		return c.params.id;
	})
export default app;