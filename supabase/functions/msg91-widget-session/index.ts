type JsonObject = Record<string, unknown>;

const corsHeaders = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, apikey, content-type, x-client-info",
  "access-control-allow-methods": "POST, OPTIONS",
  "content-type": "application/json; charset=utf-8",
};

function jsonResponse(body: JsonObject, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders });
}

function digits(value: string): string {
  return value.replace(/\D/g, "");
}

function normalizeIndianPhone(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const valueDigits = digits(value);
  const mobile = valueDigits.startsWith("91") ? valueDigits.slice(2) : valueDigits;
  if (!/^[6-9]\d{9}$/.test(mobile)) return null;
  return "+91" + mobile;
}

function randomPassword(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  const randomPart = Array.from(bytes, (value) => value.toString(16).padStart(2, "0")).join("");
  return randomPart + "Aa9!";
}

async function msg91VerifyAccessToken(authKey: string, accessToken: string): Promise<string | null> {
  const response = await fetch("https://control.msg91.com/api/v5/widget/verifyAccessToken", {
    method: "POST",
    headers: {
      accept: "application/json",
      authkey: authKey,
      "content-type": "application/json",
    },
    body: JSON.stringify({ "access-token": accessToken }),
    signal: AbortSignal.timeout(8000),
  });

  if (!response.ok) {
    console.error("MSG91 access-token verification failed with HTTP status", response.status);
    return null;
  }

  let payload: JsonObject;
  try {
    payload = await response.json() as JsonObject;
  } catch {
    return null;
  }

  if (String(payload.type ?? "").toLowerCase() !== "success") return null;
  const data = payload.data && typeof payload.data === "object" ? payload.data as JsonObject : {};
  const candidates = [
    payload.mobile, payload.phone, payload.identifier, payload.message,
    data.mobile, data.phone, data.identifier, data.message,
  ];
  for (const candidate of candidates) {
    const phone = normalizeIndianPhone(candidate);
    if (phone) return phone;
  }
  return null;
}

async function adminRequest(
  url: string,
  serviceKey: string,
  path: string,
  init: RequestInit = {},
): Promise<Response> {
  return await fetch(url + "/auth/v1" + path, {
    ...init,
    headers: {
      apikey: serviceKey,
      authorization: "Bearer " + serviceKey,
      "content-type": "application/json",
      ...(init.headers ?? {}),
    },
    signal: init.signal ?? AbortSignal.timeout(8000),
  });
}

async function findAuthUserByPhone(
  supabaseUrl: string,
  serviceKey: string,
  phone: string,
): Promise<JsonObject | null> {
  for (let page = 1; page <= 100; page += 1) {
    const response = await adminRequest(
      supabaseUrl,
      serviceKey,
      "/admin/users?page=" + page + "&per_page=1000",
      { method: "GET" },
    );
    if (!response.ok) {
      console.error("Supabase Admin user lookup failed with HTTP status", response.status);
      throw new Error("Unable to look up the account");
    }

    const payload = await response.json() as { users?: JsonObject[] };
    const users = Array.isArray(payload.users) ? payload.users : [];
    const match = users.find((user) =>
      typeof user.phone === "string" && digits(user.phone) === digits(phone)
    );
    if (match) return match;
    if (users.length < 1000) return null;
  }
  throw new Error("User lookup limit reached");
}

async function findProfileByPhone(
  supabaseUrl: string,
  serviceKey: string,
  phone: string,
): Promise<JsonObject | null> {
  const phoneDigits = digits(phone);
  const mobile = phoneDigits.startsWith('91') ? phoneDigits.slice(2) : phoneDigits;
  const variants = ['+' + phoneDigits, phoneDigits, mobile];
  const filter = 'in.(' + variants.map((value) => '"' + value + '"').join(',') + ')';
  const query = new URLSearchParams({ select: 'id,phone', phone: filter });
  const response = await fetch(supabaseUrl + '/rest/v1/profiles?' + query.toString(), {
    method: 'GET',
    headers: { apikey: serviceKey, authorization: 'Bearer ' + serviceKey },
    signal: AbortSignal.timeout(8000),
  });
  if (!response.ok) {
    console.error('Supabase profile lookup failed with HTTP status', response.status);
    throw new Error('Unable to look up the account');
  }
  const rows = await response.json() as JsonObject[];
  return Array.isArray(rows) && rows.length > 0 ? rows[0] : null;
}
async function createOrRotateWidgetUser(
  supabaseUrl: string,
  serviceKey: string,
  anonKey: string,
  phone: string,
): Promise<JsonObject> {
  let user = await findAuthUserByPhone(supabaseUrl, serviceKey, phone);
  const password = randomPassword();

  if (user) {
    const appMetadata = user.app_metadata && typeof user.app_metadata === "object"
      ? user.app_metadata as JsonObject
      : {};
    if (appMetadata.nokha_auth_provider !== "msg91_widget") {
      throw new Error("ACCOUNT_EXISTS_USE_EXISTING_LOGIN");
    }

    const userId = user.id;
    if (typeof userId !== "string") throw new Error("Invalid account record");
    const updateResponse = await adminRequest(
      supabaseUrl,
      serviceKey,
      "/admin/users/" + encodeURIComponent(userId),
      { method: "PUT", body: JSON.stringify({ password, phone_confirm: true }) },
    );
    if (!updateResponse.ok) {
      console.error("Supabase Admin password rotation failed with HTTP status", updateResponse.status);
      throw new Error("Unable to prepare the phone session");
    }
  } else {
    // Do not create a second auth identity if an existing email/password user's profile already uses this number.
    const existingProfile = await findProfileByPhone(supabaseUrl, serviceKey, phone);
    if (existingProfile) throw new Error('ACCOUNT_EXISTS_USE_EXISTING_LOGIN');
    const createResponse = await adminRequest(
      supabaseUrl,
      serviceKey,
      "/admin/users",
      {
        method: "POST",
        body: JSON.stringify({
          phone: phone,
          phone_confirm: true,
          password: password,
          app_metadata: { nokha_auth_provider: "msg91_widget" },
          user_metadata: { full_name: "" },
        }),
      },
    );

    if (!createResponse.ok) {
      if (createResponse.status === 422 || createResponse.status === 409) {
        user = await findAuthUserByPhone(supabaseUrl, serviceKey, phone);
        const appMetadata = user?.app_metadata && typeof user.app_metadata === "object"
          ? user.app_metadata as JsonObject
          : {};
        if (!user || appMetadata.nokha_auth_provider !== "msg91_widget") {
          throw new Error("ACCOUNT_EXISTS_USE_EXISTING_LOGIN");
        }
        const userId = user.id;
        if (typeof userId !== "string") throw new Error("Invalid account record");
        const updateResponse = await adminRequest(
          supabaseUrl,
          serviceKey,
          "/admin/users/" + encodeURIComponent(userId),
          { method: "PUT", body: JSON.stringify({ password, phone_confirm: true }) },
        );
        if (!updateResponse.ok) throw new Error("Unable to prepare the phone session");
      } else {
        console.error("Supabase Admin user creation failed with HTTP status", createResponse.status);
        throw new Error("Unable to create the phone account");
      }
    }
  }

  const loginResponse = await fetch(supabaseUrl + "/auth/v1/token?grant_type=password", {
    method: "POST",
    headers: { apikey: anonKey, "content-type": "application/json" },
    body: JSON.stringify({ phone: phone, password: password }),
    signal: AbortSignal.timeout(8000),
  });
  if (!loginResponse.ok) {
    console.error("Supabase phone session creation failed with HTTP status", loginResponse.status);
    throw new Error("Unable to create a login session. Please retry.");
  }
  return await loginResponse.json() as JsonObject;
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method === "OPTIONS") return new Response("ok", { status: 200, headers: corsHeaders });
  if (request.method !== "POST") return jsonResponse({ error: "Method not allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL")?.trim();
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim();
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")?.trim();
  const msg91AuthKey = Deno.env.get("MSG91_AUTH_KEY")?.trim();
  if (!supabaseUrl || !serviceKey || !anonKey || !msg91AuthKey) {
    console.error("MSG91 widget session function is missing required server configuration");
    return jsonResponse({ error: "Phone login is not configured yet" }, 503);
  }

  let body: JsonObject;
  try {
    const rawBody = await request.text();
    if (rawBody.length > 16384) return jsonResponse({ error: "Request is too large" }, 413);
    body = JSON.parse(rawBody) as JsonObject;
  } catch {
    return jsonResponse({ error: "Invalid request body" }, 400);
  }

  const accessToken = body.accessToken;
  if (typeof accessToken !== "string" || accessToken.length < 20 || accessToken.length > 8192) {
    return jsonResponse({ error: "A valid MSG91 access token is required" }, 400);
  }

  let verifiedPhone: string | null;
  try {
    verifiedPhone = await msg91VerifyAccessToken(msg91AuthKey, accessToken);
  } catch {
    console.error("MSG91 verification request could not be completed");
    return jsonResponse({ error: "Phone verification is temporarily unavailable" }, 502);
  }
  if (!verifiedPhone) return jsonResponse({ error: "MSG91 could not verify this phone session" }, 401);

  const expectedPhone = normalizeIndianPhone(body.phone);
  if (body.phone !== undefined && (!expectedPhone || digits(expectedPhone) !== digits(verifiedPhone))) {
    return jsonResponse({ error: "Verified phone does not match the entered number" }, 401);
  }

  try {
    const session = await createOrRotateWidgetUser(supabaseUrl, serviceKey, anonKey, verifiedPhone);
    if (typeof session.access_token !== "string" || typeof session.refresh_token !== "string") {
      return jsonResponse({ error: "Supabase did not return a valid session" }, 502);
    }
    return jsonResponse({
      access_token: session.access_token,
      refresh_token: session.refresh_token,
      expires_in: session.expires_in,
      token_type: session.token_type,
      user: session.user,
    });
  } catch (error) {
    if (error instanceof Error && error.message === "ACCOUNT_EXISTS_USE_EXISTING_LOGIN") {
      return jsonResponse({
        error: "An account already exists for this number. Please use your existing email/password login.",
        code: "ACCOUNT_EXISTS_USE_EXISTING_LOGIN",
      }, 409);
    }
    console.error("MSG91 phone session could not be established");
    return jsonResponse({ error: "Unable to complete phone login. Please retry." }, 500);
  }
});
