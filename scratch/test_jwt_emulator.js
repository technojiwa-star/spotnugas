const http = require('http');

function createToken(payload) {
  const header = { alg: 'none', typ: 'JWT' };
  const b64 = (obj) => Buffer.from(JSON.stringify(obj)).toString('base64url');
  return `${b64(header)}.${b64(payload)}.`;
}

function request({ method, path, token, body }) {
  return new Promise((resolve, reject) => {
    const headers = { 'Content-Type': 'application/json' };
    if (token) headers['Authorization'] = `Bearer ${token}`;
    const req = http.request(
      {
        hostname: '127.0.0.1',
        port: 8080,
        path: `/v1/projects/spotnugas-c2781/databases/(default)/documents${path}`,
        method,
        headers,
      },
      (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => {
          resolve({ status: res.statusCode, body: data ? JSON.parse(data) : {} });
        });
      }
    );
    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

async function run() {
  const regUser = createToken({
    sub: 'user_reg_1',
    user_id: 'user_reg_1',
    firebase: { sign_in_provider: 'password' },
  });
  const guestUser = createToken({
    sub: 'guest_1',
    user_id: 'guest_1',
    firebase: { sign_in_provider: 'anonymous' },
  });

  // Test 1: Public places read
  const res1 = await request({ method: 'GET', path: '/places/kopi-ruang' });
  console.log('Test 1 (Public read places):', res1.status);

  // Test 2: Unauth write to places (should be 403)
  const res2 = await request({
    method: 'PATCH',
    path: '/places/kopi-ruang',
    body: { fields: { studyScore: { doubleValue: 9.9 } } },
  });
  console.log('Test 2 (Direct write to places unauth):', res2.status);

  // Test 3: Registered user direct write to places (should be 403 denied)
  const res3 = await request({
    method: 'PATCH',
    path: '/places/kopi-ruang',
    token: regUser,
    body: { fields: { studyScore: { doubleValue: 9.9 } } },
  });
  console.log('Test 3 (Registered direct write to studyScore):', res3.status);

  // Test 4: Guest user saves bookmark under own UID (should be 200/allowed)
  const res4 = await request({
    method: 'PATCH',
    path: '/users/guest_1/saved_places/kopi-ruang',
    token: guestUser,
    body: {
      fields: {
        placeId: { stringValue: 'kopi-ruang' },
        savedAt: { timestampValue: new Date().toISOString() },
      },
    },
  });
  console.log('Test 4 (Guest saves bookmark under own UID):', res4.status);

  // Test 5: Guest attempts to read another user's bookmark (should be 403 denied)
  const res5 = await request({
    method: 'GET',
    path: '/users/user_reg_1/saved_places/kopi-ruang',
    token: guestUser,
  });
  console.log('Test 5 (Guest reads another user saved places):', res5.status);
}

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
