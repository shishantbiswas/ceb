import { Hono } from 'hono'
import { logger } from 'hono/logger'

const app = new Hono()

app.use(logger());
const fav = await Bun.file("../docs/assets/favicon.svg").bytes()

app.get("/favicon.svg",async (c)=>{
  return await c.body(fav);
});

app.get(
  '/heyo',
  async (c) => {
    c.status(200);
    return c.text("Hello World")
  },
)

export default app;