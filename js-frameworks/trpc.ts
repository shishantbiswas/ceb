import { initTRPC, TRPCError } from '@trpc/server'
import { z } from 'zod'

import { fileTypeFromBuffer } from 'file-type'

const t = initTRPC.create()

export const uploadRouter = t.router({
	uploadImage: t.procedure
		.input(z.base64())
		.mutation(async ({ input }) => {
			const buffer = Buffer.from(input, 'base64')

			const type = await fileTypeFromBuffer(buffer)
			if (!type || !type.mime.startsWith('image/'))
				throw new TRPCError({
      				code: 'UNPROCESSABLE_CONTENT',
       				message: 'Invalid file type',
    			})

			return input
		})
})