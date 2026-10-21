const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json; charset=utf-8",
  "Cache-Control": "private, no-store",
};

type JsonObject = Record<string, unknown>;

function reply(body: JsonObject, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders });
}

function serviceHeaders(serviceKey: string): HeadersInit {
  return {
    apikey: serviceKey,
    authorization: "Bearer " + serviceKey,
    "content-type": "application/json",
  };
}

async function readJson(response: Response): Promise<unknown> {
  try {
    return await response.json();
  } catch {
    return null;
  }
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method === "OPTIONS") return new Response("ok", { status: 200, headers: corsHeaders });
  if (request.method !== "POST") return reply({ error: "Method not allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL")?.trim();
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")?.trim();
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim();
  const authorization = request.headers.get("Authorization");

  if (!supabaseUrl || !anonKey || !serviceKey) {
    console.error("Owner vehicle catalog is missing required server configuration");
    return reply({ error: "Vehicle catalog is temporarily unavailable" }, 503);
  }
  if (!authorization?.startsWith("Bearer ")) {
    return reply({ error: "Sign in to view the vehicle catalog" }, 401);
  }

  try {
    const userResponse = await fetch(supabaseUrl + "/auth/v1/user", {
      headers: { apikey: anonKey, authorization },
      signal: AbortSignal.timeout(8000),
    });
    if (!userResponse.ok) return reply({ error: "Your session is invalid or expired" }, 401);
    const user = await readJson(userResponse) as JsonObject | null;
    const userId = user && typeof user.id === "string" ? user.id : null;
    if (!userId) return reply({ error: "Unable to verify your account" }, 401);

    const roleQuery = new URLSearchParams({ select: "role", user_id: "eq." + userId });
    const roleResponse = await fetch(supabaseUrl + "/rest/v1/user_roles?" + roleQuery, {
      headers: serviceHeaders(serviceKey),
      signal: AbortSignal.timeout(8000),
    });
    if (!roleResponse.ok) {
      console.error("Owner role lookup failed with HTTP status", roleResponse.status);
      return reply({ error: "Unable to verify owner access" }, 502);
    }
    const roles = await readJson(roleResponse) as JsonObject[];
    if (!Array.isArray(roles) || !roles.some((row) => row.role === "OWNER")) {
      return reply({ error: "Only owner accounts can view the owner vehicle catalog" }, 403);
    }

    const [categoryResponse, modelResponse, requirementResponse] = await Promise.all([
      fetch(
        supabaseUrl + "/rest/v1/vehicle_categories?select=id,name,is_bike,is_passenger_vehicle,is_active,sort_order&is_active=eq.true&is_bike=eq.false&is_passenger_vehicle=eq.true&order=sort_order.asc",
        { headers: serviceHeaders(serviceKey), signal: AbortSignal.timeout(8000) },
      ),
      fetch(
        supabaseUrl + "/rest/v1/vehicle_models?select=id,vehicle_category_id,brand,model_name,variant,default_seats,default_ac,is_active&is_active=eq.true&order=brand.asc,model_name.asc",
        { headers: serviceHeaders(serviceKey), signal: AbortSignal.timeout(8000) },
      ),
      fetch(
        supabaseUrl + "/rest/v1/vehicle_document_requirements?select=vehicle_category_id,document_type,is_required,expiry_required,requires_admin_verification,is_active&is_active=eq.true&is_required=eq.true",
        { headers: serviceHeaders(serviceKey), signal: AbortSignal.timeout(8000) },
      ),
    ]);

    if (!categoryResponse.ok || !modelResponse.ok || !requirementResponse.ok) {
      console.error("Owner vehicle catalog query failed", categoryResponse.status, modelResponse.status, requirementResponse.status);
      return reply({ error: "Vehicle catalog could not be loaded. Please retry." }, 502);
    }

    const categories = await readJson(categoryResponse) as JsonObject[];
    const allModels = await readJson(modelResponse) as JsonObject[];
    const allRequirements = await readJson(requirementResponse) as JsonObject[];
    if (!Array.isArray(categories) || !Array.isArray(allModels) || !Array.isArray(allRequirements)) {
      return reply({ error: "Vehicle catalog returned an invalid response" }, 502);
    }

    const categoryIds = new Set(
      categories.filter((row) => row.is_active === true && row.is_bike === false && row.is_passenger_vehicle === true)
        .map((row) => String(row.id)),
    );
    const allowedCategories = categories.filter((row) => categoryIds.has(String(row.id)));
    const models = allModels
      .filter((row) => row.is_active === true && categoryIds.has(String(row.vehicle_category_id)))
      .map((row) => ({
        id: row.id,
        vehicle_category_id: row.vehicle_category_id,
        brand: row.brand,
        model_name: row.model_name,
        variant: row.variant,
        default_seats: row.default_seats,
        default_ac: row.default_ac,
      }));
    const requirements = allRequirements.filter((row) => categoryIds.has(String(row.vehicle_category_id)));

    return reply({ categories: allowedCategories, models, required_documents: requirements });
  } catch (error) {
    console.error("Owner vehicle catalog request failed", error instanceof Error ? error.name : "unknown");
    return reply({ error: "Vehicle catalog is temporarily unavailable. Please retry." }, 500);
  }
});
