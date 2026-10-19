import { Webhook } from 'https://esm.sh/standardwebhooks@1.0.0'

type HookPayload = {
  user?: { phone?: string | null }
  sms?: { otp?: string | null }
}

function jsonError(message: string, status = 400): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8' },
  })
}

function normalizeMobile(phone: string): string {
  const digits = phone.replace(/[^0-9]/g, '')
  // This deployment is configured for Indian mobile numbers only.
  if (!/^91[6-9][0-9]{9}$/.test(digits)) {
    throw new Error('Unsupported phone number format')
  }
  return digits
}

function verifyHookPayload(rawBody: string, headers: Headers): HookPayload {
  const configured = Deno.env.get('SEND_SMS_HOOK_SECRET')?.trim()
  if (!configured) throw new Error('SMS hook secret is not configured')

  const secrets = configured
    .split('|')
    .map((value) => value.trim())
    .filter(Boolean)

  for (const prefixedSecret of secrets) {
    const secret = prefixedSecret.replace(/^v1,whsec_/, '')
    try {
      const webhook = new Webhook(secret)
      return webhook.verify(rawBody, Object.fromEntries(headers.entries())) as HookPayload
    } catch {
      // During secret rotation, try the next configured secret.
    }
  }

  throw new Error('Invalid SMS hook signature')
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', {
      status: 405,
      headers: { allow: 'POST' },
    })
  }

  let payload: HookPayload
  try {
    const rawBody = await req.text()
    payload = verifyHookPayload(rawBody, req.headers)
  } catch (error) {
    console.error('SMS hook request rejected:', error instanceof Error ? error.message : 'signature verification failed')
    return jsonError('Unauthorized SMS hook request', 401)
  }

  const authKey = Deno.env.get('MSG91_AUTH_KEY')?.trim()
  const templateId = Deno.env.get('MSG91_TEMPLATE_ID')?.trim()
  const otpVariable = (Deno.env.get('MSG91_OTP_VARIABLE') ?? 'VAR1').trim()
  const phone = payload.user?.phone
  const otp = payload.sms?.otp

  if (!authKey || !templateId) {
    console.error('MSG91 configuration is incomplete')
    return jsonError('SMS provider is not configured', 500)
  }

  if (!/^[A-Za-z0-9_]{1,32}$/.test(otpVariable)) {
    console.error('MSG91_OTP_VARIABLE has an invalid format')
    return jsonError('SMS provider configuration is invalid', 500)
  }

  if (typeof phone !== 'string' || typeof otp !== 'string' || !/^[0-9]{6}$/.test(otp)) {
    return jsonError('Invalid OTP event payload', 400)
  }

  let mobile: string
  try {
    mobile = normalizeMobile(phone)
  } catch {
    return jsonError('Only valid Indian mobile numbers are supported', 400)
  }

  const recipient: Record<string, string> = { mobiles: mobile }
  recipient[otpVariable] = otp

  let providerResponse: Response
  try {
    providerResponse = await fetch('https://control.msg91.com/api/v5/flow', {
      method: 'POST',
      headers: {
        accept: 'application/json',
        authkey: authKey,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        template_id: templateId,
        short_url: '0',
        realTimeResponse: '1',
        recipients: [recipient],
      }),
      signal: AbortSignal.timeout(10000),
    })
  } catch {
    console.error('MSG91 request failed before receiving a response')
    return jsonError('SMS provider is temporarily unavailable', 502)
  }

  const responseText = await providerResponse.text()
  let providerBody: Record<string, unknown> = {}
  try {
    providerBody = JSON.parse(responseText) as Record<string, unknown>
  } catch {
    // A non-JSON response is treated as a provider failure below.
  }

  const providerType = String(providerBody.type ?? '').toLowerCase()
  const providerStatus = String(providerBody.status ?? '').toLowerCase()
  const providerFailed =
    !providerResponse.ok ||
    providerType === 'error' ||
    providerStatus === 'error' ||
    providerStatus === 'failed'

  if (providerFailed) {
    // Do not log the request, OTP, auth key, or provider response body.
    console.error('MSG91 rejected the OTP SMS request; HTTP status:', providerResponse.status)
    return jsonError('SMS delivery could not be requested', 502)
  }

  // Supabase Auth expects a 2xx response with no required response body.
  return new Response(null, { status: 200 })
})
