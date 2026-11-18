import { createClient } from 'npm:@supabase/supabase-js@2.106.1';

const cache = new Map<string, {expires: number; value: unknown}>();
const recent = new Map<string, number>();
const groups: Record<string, string> = {
  Dining: 'catering.restaurant,catering.cafe',
  Resort: 'accommodation.hotel',
  Nature: 'leisure.park,natural.forest,natural.protected_area',
  Riverside: 'natural.water.river_system,beach,maritime.marina,man_made.pier',
  Culture: 'entertainment.museum,entertainment.culture.gallery,entertainment.culture.arts_centre,tourism.sights.place_of_worship.temple,tourism.sights.fort',
  Hills: 'natural.mountain.hill,natural.mountain.peak,tourism.attraction.viewpoint',
  Outdoors: 'leisure.picnic.picnic_site,camping.camp_site,national_park',
  Playful: 'entertainment.cinema,entertainment.bowling_alley,entertainment.amusement_arcade,entertainment.zoo,entertainment.theme_park',
  'Bike ride': 'highway.cycleway,tourism.sights.bridge,leisure.park.garden',
};
const excludedName = /\b(gym|fitness|football|soccer|stadium|bank|atm|hospital|clinic|medical|guest\s*house|hostel|private\s*house|residence|apartment|market|bazaar|wholesale|warehouse|school|college|office|bus\s*stop|parking)\b/i;
const excludedCategory = /^(sport|healthcare|office|education|public_transport|accommodation\.guest_house)(\.|$)/;
function copyFor(category: string, name: string, tags: string[]) {
  const title = category === 'Dining' ? `${tags.some((tag) => tag.includes('cafe')) ? 'Coffee' : 'Dinner'} at ${name}` :
    category === 'Resort' ? `A little escape to ${name}` :
    category === 'Nature' ? `A slow walk at ${name}` :
    category === 'Riverside' ? `An afternoon by ${name}` :
    category === 'Culture' ? `Explore ${name} together` :
    category === 'Hills' ? `A view from ${name}` :
    category === 'Outdoors' ? `A day outside at ${name}` :
    category === 'Playful' ? `A playful date at ${name}` : `Ride towards ${name}`;
  const description = category === 'Dining' ? 'Good food, easy conversation, and time to linger together.' :
    category === 'Resort' ? 'Make room for an unhurried afternoon together. Check access and booking first.' :
    category === 'Nature' ? 'Take the scenic path and enjoy the quiet moments between stops.' :
    category === 'Riverside' ? 'Follow the water, find a comfortable spot, and watch the day unfold.' :
    category === 'Culture' ? 'See something beautiful and share what it makes you think of.' :
    category === 'Hills' ? 'Go for the view and stay for the company. Check the route first.' :
    category === 'Outdoors' ? 'Fresh air, a little adventure, and a date made your own.' :
    category === 'Playful' ? 'Laugh together and make a small story to remember.' :
    'A destination for your ride together. Plan a safe route before setting off.';
  return {title, description};
}
const respond = (value: unknown, status = 200) => Response.json(value, {status});
async function geo(path: string, params: Record<string, string>, key: string) {
  const url = new URL(`https://api.geoapify.com/${path}`);
  for (const [name, value] of Object.entries(params)) url.searchParams.set(name, value);
  url.searchParams.set('apiKey', key);
  const result = await fetch(url, {signal: AbortSignal.timeout(15000)});
  if (!result.ok) throw new Error('Place provider unavailable');
  return await result.json();
}
function distance(lat1: number, lon1: number, lat2: number, lon2: number) {
  const rad = Math.PI / 180;
  const a = Math.sin((lat2-lat1)*rad/2)**2 + Math.cos(lat1*rad)*Math.cos(lat2*rad)*Math.sin((lon2-lon1)*rad/2)**2;
  return 6371000 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
}
Deno.serve(async request => {
  if (request.method !== 'POST') return respond({error: 'Method not allowed'}, 405);
  const authorization = request.headers.get('Authorization') ?? '';
  const client = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, {global: {headers: {Authorization: authorization}}});
  const {data: {user}} = await client.auth.getUser();
  if (!user) return respond({error: 'Sign in required'}, 401);
  const {data: profile} = await client.from('profiles').select('couple_id').eq('id', user.id).single();
  if (!profile?.couple_id) return respond({error: 'Join your shared space first'}, 403);
  const key = Deno.env.get('GEOAPIFY_API_KEY');
  if (!key) return respond({error: 'Nearby ideas are being connected. You can enter a venue manually.', code: 'provider_not_configured'}, 503);
  let body;
  try { body = await request.json(); } catch { return respond({error: 'Invalid request'}, 400); }
  const {latitude: lat, longitude: lon, radius} = body;
  if (typeof lat !== 'number' || typeof lon !== 'number' || !Number.isFinite(lat) || !Number.isFinite(lon) || Math.abs(lat)>90 || Math.abs(lon)>180 || ![15000,50000,100000].includes(radius)) return respond({error: 'Invalid search area'}, 400);
  // Short-lived in-memory caching: no personal coordinates are persisted.
  const cell = `${lat.toFixed(2)}:${lon.toFixed(2)}:${radius}`;
  const hit = cache.get(cell);
  if (hit && hit.expires > Date.now()) return respond(hit.value);
  if ((recent.get(user.id) ?? 0)>Date.now()-10000) return respond({error: 'Please wait a moment before searching again.'}, 429);
  recent.set(user.id, Date.now());
  if (recent.size>1000) recent.delete(recent.keys().next().value!);
  try {
    const address = await geo('v1/geocode/reverse', {lat: String(lat), lon: String(lon), format: 'json'}, key);
    // Wider searches sample the centre and four surrounding sectors, so dense
    // city listings do not crowd out neighbouring towns. Results remain bounded
    // by the selected radius; this is discovery, not an exhaustive POI census.
    const deltaLat = radius * .6 / 111320;
    const deltaLon = deltaLat / Math.max(.15, Math.cos(lat*Math.PI/180));
    const anchors = radius>15000 ? [[lon,lat],[lon+deltaLon,lat],[lon-deltaLon,lat],[lon,Math.min(89.9,lat+deltaLat)],[lon,Math.max(-89.9,lat-deltaLat)]] : [[lon,lat]];
    const results = await Promise.all(Object.values(groups).map(async (categories, index) => {
      const chosen = radius>15000 ? [anchors[0], anchors[1+(index%4)]] : [anchors[0]];
      const responses = await Promise.all(chosen.map(async ([x,y]) =>
        geo('v2/places', {categories, filter: `circle:${lon},${lat},${radius}`, bias: `proximity:${((x+540)%360)-180},${y}`, limit: '35'}, key)));
      return {features: responses.flatMap(result => result.features ?? [])};
    }));
    const region = address.results?.[0] ?? {};
    const names = Object.keys(groups);
    const seen = new Set<string>();
    const buckets = results.map((result, index) => (result.features ?? []).flatMap((feature: any) => {
      const p = feature.properties;
      if (!p?.name || seen.has(p.place_id) || excludedName.test(p.name)) return [];
      const tags: string[] = p.categories ?? [];
      if (tags.some(tag => excludedCategory.test(tag))) return [];
      seen.add(p.place_id);
      const metres = distance(lat, lon, p.lat, p.lon);
      if (!Number.isFinite(metres) || metres>radius) return [];
      // Prefer nearby named places with useful address details; interleave categories below.
      const score = 1/(1+metres/10000) + (p.address_line2 ? .12 : 0);
      const copy = copyFor(names[index], p.name, tags);
      return [{id: p.place_id, name: p.name, address: p.formatted ?? p.address_line2 ?? '', latitude: p.lat, longitude: p.lon, distance: Math.round(metres), category: names[index], ...copy, score}];
    }).sort((a: any,b: any) => b.score-a.score));
    // Alternate nearby and further-away candidates within each activity group.
    if (radius>15000) for (const bucket of buckets) {
      const near = bucket.filter((p: any) => p.distance<15000);
      const far = bucket.filter((p: any) => p.distance>=15000);
      bucket.length = 0;
      for (let i=0; i<Math.max(near.length,far.length); i++) {
        if (near[i]) bucket.push(near[i]);
        if (far[i]) bucket.push(far[i]);
      }
    }
    const places = [];
    for (let i=0; i<20; i++) for (const bucket of buckets) if (bucket[i]) places.push(bucket[i]);
    const value = {city: region.city ?? region.town ?? region.county ?? 'Around you', district: region.county ?? region.state_district ?? '', radius, places, attribution: 'Geoapify / OpenStreetMap contributors', fetched_at: new Date().toISOString()};
    if (cache.size>=100) cache.delete(cache.keys().next().value!);
    cache.set(cell, {expires: Date.now()+15*60*1000, value});
    return respond(value);
  } catch { return respond({error: 'Nearby places could not load. Please retry shortly.'}, 502); }
});
