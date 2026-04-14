import { Hono } from 'hono'
import { logger } from 'hono/logger'

const app = new Hono()

app.use(logger());

app.get(
  '/heyo',
  async (c) => {
    c.status(200);
    return c.text("Hello World")
  },
)

app.get(
  '/json',
  async (c) => {
    c.status(200);
    return c.json({
      message: "Hello World"
    })
  },
)

export default app;