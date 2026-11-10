/**
 * SpotNugas Firestore Security Rules Test Suite
 * Validated against Firebase Firestore Emulator Suite.
 *
 * Covers all allowed and denied operations required by Phase D4:
 * 1. Owner can save/unsave bookmarks.
 * 2. Another user cannot read/write private saved data.
 * 3. Anonymous guest can save under own UID.
 * 4. Anonymous guest CANNOT publish a review.
 * 5. Registered user CAN publish one review per place.
 * 6. User cannot publish a review with mismatched reviewId.
 * 7. User cannot edit another user's review.
 * 8. Invalid rating values (< 1.0, > 5.0, non-numeric) are rejected.
 * 9. Identity/ownership fields (userId, placeId, createdAt) are immutable on update.
 * 10. Direct writes to places/studyScore/aggregate counters are denied.
 * 11. Unauthorized place/partner/admin writes are denied.
 * 12. Privacy leak prevention: email, userEmail, phoneNumber in reviews are denied.
 * 13. Profile role escalation prevention: regular users cannot become admin/partner.
 */

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
          let parsed = {};
          try {
            if (data) parsed = JSON.parse(data);
          } catch (_) {}
          resolve({ status: res.statusCode, body: parsed });
        });
      }
    );
    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

// Helper users
const userAlice = createToken({
  sub: 'alice_uid',
  user_id: 'alice_uid',
  firebase: { sign_in_provider: 'password' },
});

const userBob = createToken({
  sub: 'bob_uid',
  user_id: 'bob_uid',
  firebase: { sign_in_provider: 'password' },
});

const guestUser = createToken({
  sub: 'guest_charlie_uid',
  user_id: 'guest_charlie_uid',
  firebase: { sign_in_provider: 'anonymous' },
});

const adminUser = createToken({
  sub: 'admin_uid',
  user_id: 'admin_uid',
  role: 'admin',
  firebase: { sign_in_provider: 'password' },
});

let totalTests = 0;
let passedTests = 0;

function assert(condition, testName) {
  totalTests++;
  if (condition) {
    passedTests++;
    console.log(`  ✔ [PASS] ${testName}`);
  } else {
    console.error(`  ✘ [FAIL] ${testName}`);
    process.exitCode = 1;
  }
}

async function runTests() {
  console.log('\n============================================================');
  console.log('--- STARTING FIRESTORE SECURITY RULES VALIDATION SUITE ---');
  console.log('============================================================\n');

  // ──────────────────────────────────────────────────────────────────────────
  // 1. Users & Profiles
  // ──────────────────────────────────────────────────────────────────────────
  console.log('1. User Profile Rules:');

  // Alice can create her own profile with role: 'user'
  const createAlice = await request({
    method: 'PATCH',
    path: '/users/alice_uid',
    token: userAlice,
    body: {
      fields: {
        uid: { stringValue: 'alice_uid' },
        name: { stringValue: 'Alice Test' },
        email: { stringValue: 'alice@example.com' },
        role: { stringValue: 'user' },
      },
    },
  });
  assert(createAlice.status === 200, 'Owner can create own profile with role user');

  // Alice cannot self-assign role: 'admin'
  const createAliceAdmin = await request({
    method: 'PATCH',
    path: '/users/alice_admin_attempt',
    token: userAlice,
    body: {
      fields: {
        uid: { stringValue: 'alice_admin_attempt' },
        name: { stringValue: 'Alice Hacker' },
        role: { stringValue: 'admin' },
      },
    },
  });
  assert(createAliceAdmin.status === 403, 'User CANNOT self-escalate role to admin on profile creation');

  // Bob cannot read Alice's profile
  const bobReadsAlice = await request({
    method: 'GET',
    path: '/users/alice_uid',
    token: userBob,
  });
  assert(bobReadsAlice.status === 403, 'Another user CANNOT read private user profile');

  // Alice can read her own profile
  const aliceReadsAlice = await request({
    method: 'GET',
    path: '/users/alice_uid',
    token: userAlice,
  });
  assert(aliceReadsAlice.status === 200, 'Owner CAN read own user profile');

  // Alice CANNOT delete her own user profile (allow delete: if false)
  const aliceDeletesProfile = await request({
    method: 'DELETE',
    path: '/users/alice_uid',
    token: userAlice,
  });
  assert(aliceDeletesProfile.status === 403, 'User CANNOT delete profile directly (deletion disabled)');

  // Profile creation with arbitrary extra injected fields is DENIED
  const createWithExtraFields = await request({
    method: 'PATCH',
    path: '/users/alice_extra_test',
    token: userAlice,
    body: {
      fields: {
        uid: { stringValue: 'alice_extra_test' },
        name: { stringValue: 'Alice Extra' },
        role: { stringValue: 'user' },
        injectedHackerField: { stringValue: 'malicious' },
      },
    },
  });
  assert(createWithExtraFields.status === 403, 'Profile with arbitrary injected fields is REJECTED');

  // Client role escalation on update is DENIED
  const aliceEscalatesRole = await request({
    method: 'PATCH',
    path: '/users/alice_uid',
    token: userAlice,
    body: {
      fields: {
        uid: { stringValue: 'alice_uid' },
        name: { stringValue: 'Alice Test' },
        role: { stringValue: 'admin' },
      },
    },
  });
  assert(aliceEscalatesRole.status === 403, 'Client role escalation on profile update is DENIED');

  // ──────────────────────────────────────────────────────────────────────────
  // 2. Bookmarks / Saved Places: /users/{userId}/saved_places/{placeId}
  // ──────────────────────────────────────────────────────────────────────────
  console.log('\n2. Bookmarks / Saved Places Rules:');

  const nowIso = new Date().toISOString();

  // Alice can save bookmark
  const aliceSaves = await request({
    method: 'PATCH',
    path: '/users/alice_uid/saved_places/kopi-ruang',
    token: userAlice,
    body: {
      fields: {
        placeId: { stringValue: 'kopi-ruang' },
        name: { stringValue: 'Kopi Ruang' },
        savedAt: { timestampValue: nowIso },
      },
    },
  });
  assert(aliceSaves.status === 200, 'Owner can save place bookmark under own UID');

  // Alice can unsave (delete) bookmark
  const aliceUnsaves = await request({
    method: 'DELETE',
    path: '/users/alice_uid/saved_places/kopi-ruang',
    token: userAlice,
  });
  assert(aliceUnsaves.status === 200, 'Owner can unsave (delete) own place bookmark');

  // Resave for read testing
  await request({
    method: 'PATCH',
    path: '/users/alice_uid/saved_places/kopi-ruang',
    token: userAlice,
    body: {
      fields: {
        placeId: { stringValue: 'kopi-ruang' },
        savedAt: { timestampValue: nowIso },
      },
    },
  });

  // Bob CANNOT read Alice's bookmarks
  const bobReadsAliceBookmark = await request({
    method: 'GET',
    path: '/users/alice_uid/saved_places/kopi-ruang',
    token: userBob,
  });
  assert(bobReadsAliceBookmark.status === 403, 'Another user CANNOT read private saved data');

  // Bob CANNOT write to Alice's bookmarks
  const bobWritesAliceBookmark = await request({
    method: 'PATCH',
    path: '/users/alice_uid/saved_places/kopi-ruang',
    token: userBob,
    body: {
      fields: {
        placeId: { stringValue: 'kopi-ruang' },
        savedAt: { timestampValue: nowIso },
      },
    },
  });
  assert(bobWritesAliceBookmark.status === 403, 'Another user CANNOT write to private saved data');

  // Anonymous guest CAN save under their own UID
  const guestSavesOwn = await request({
    method: 'PATCH',
    path: '/users/guest_charlie_uid/saved_places/kopi-ruang',
    token: guestUser,
    body: {
      fields: {
        placeId: { stringValue: 'kopi-ruang' },
        savedAt: { timestampValue: nowIso },
      },
    },
  });
  assert(guestSavesOwn.status === 200, 'Anonymous guest CAN save bookmark under own UID');

  // Anonymous guest CANNOT read another user's bookmark
  const guestReadsAlice = await request({
    method: 'GET',
    path: '/users/alice_uid/saved_places/kopi-ruang',
    token: guestUser,
  });
  assert(guestReadsAlice.status === 403, 'Anonymous guest CANNOT read another user saved data');

  // Bookmark with arbitrary extra injected fields is DENIED
  const saveWithExtraFields = await request({
    method: 'PATCH',
    path: '/users/alice_uid/saved_places/extra-field-place',
    token: userAlice,
    body: {
      fields: {
        placeId: { stringValue: 'extra-field-place' },
        name: { stringValue: 'Extra Field Place' },
        savedAt: { timestampValue: nowIso },
        maliciousInjectedField: { stringValue: 'attack' },
      },
    },
  });
  assert(saveWithExtraFields.status === 403, 'Bookmark with arbitrary injected fields is REJECTED');

  // Bookmark with invalid source is DENIED
  const saveWithInvalidSource = await request({
    method: 'PATCH',
    path: '/users/alice_uid/saved_places/bad-source-place',
    token: userAlice,
    body: {
      fields: {
        placeId: { stringValue: 'bad-source-place' },
        savedAt: { timestampValue: nowIso },
        source: { stringValue: 'untrusted_vendor' },
      },
    },
  });
  assert(saveWithInvalidSource.status === 403, 'Bookmark with invalid source is REJECTED');

  // Bookmark with valid source (geoapify) is ALLOWED
  const saveWithValidSource = await request({
    method: 'PATCH',
    path: '/users/alice_uid/saved_places/valid-source-place',
    token: userAlice,
    body: {
      fields: {
        placeId: { stringValue: 'valid-source-place' },
        name: { stringValue: 'Valid Source Place' },
        savedAt: { timestampValue: nowIso },
        source: { stringValue: 'geoapify' },
      },
    },
  });
  assert(saveWithValidSource.status === 200, 'Bookmark with valid source (geoapify) is ALLOWED');

  // Bookmark update is DENIED (create/delete only policy enforced)
  const updateBookmarkAttempt = await request({
    method: 'PATCH',
    path: '/users/alice_uid/saved_places/valid-source-place',
    token: userAlice,
    body: {
      fields: {
        placeId: { stringValue: 'valid-source-place' },
        name: { stringValue: 'Updated Name Attempt' },
        savedAt: { timestampValue: nowIso },
      },
    },
  });
  assert(updateBookmarkAttempt.status === 403, 'Bookmark update is DENIED (create/delete only policy enforced)');

  // ──────────────────────────────────────────────────────────────────────────
  // 3. Places Catalog & Aggregates Hardening: /places/{placeId}
  // ──────────────────────────────────────────────────────────────────────────
  console.log('\n3. Places Catalog & Aggregates Protection:');

  // Direct write to places is denied to unauthenticated users
  const unauthWritePlace = await request({
    method: 'PATCH',
    path: '/places/kopi-ruang',
    body: {
      fields: { studyScore: { doubleValue: 9.9 } },
    },
  });
  assert(unauthWritePlace.status === 403, 'Unauthenticated direct write to places is DENIED');

  // Direct client write to studyScore / aggregate counters is denied to registered user
  const regUserWriteScore = await request({
    method: 'PATCH',
    path: '/places/kopi-ruang',
    token: userAlice,
    body: {
      fields: {
        studyScore: { doubleValue: 9.9 },
        communityRating: { doubleValue: 5.0 },
      },
    },
  });
  assert(regUserWriteScore.status === 403, 'Direct writes to studyScore / aggregate counters are DENIED to users');

  // ──────────────────────────────────────────────────────────────────────────
  // 4. Public Reviews: /places/{placeId}/reviews/{reviewId}
  // ──────────────────────────────────────────────────────────────────────────
  console.log('\n4. Review Permissions & Content Validation:');

  const reviewCreatedAt = new Date().toISOString();

  // Anonymous guest CANNOT publish a review
  const guestReviewAttempt = await request({
    method: 'PATCH',
    path: '/places/kopi-ruang/reviews/guest_charlie_uid',
    token: guestUser,
    body: {
      fields: {
        userId: { stringValue: 'guest_charlie_uid' },
        placeId: { stringValue: 'kopi-ruang' },
        userName: { stringValue: 'Tamu SpotNugas' },
        rating: { doubleValue: 4.5 },
        comment: { stringValue: 'Kopi enak dan tempat nyaman buat nugas.' },
        createdAt: { timestampValue: reviewCreatedAt },
      },
    },
  });
  assert(guestReviewAttempt.status === 403, 'Anonymous guest CANNOT publish a review');

  // Registered user CAN publish review with reviewId == auth.uid (one review per user per place)
  const aliceReview = await request({
    method: 'PATCH',
    path: '/places/kopi-ruang/reviews/alice_uid',
    token: userAlice,
    body: {
      fields: {
        userId: { stringValue: 'alice_uid' },
        placeId: { stringValue: 'kopi-ruang' },
        userName: { stringValue: 'Alice W' },
        rating: { doubleValue: 4.8 },
        comment: { stringValue: 'Tempat sangat tenang, banyak colokan di setiap meja.' },
        createdAt: { timestampValue: reviewCreatedAt },
        wifiRating: { doubleValue: 5.0 },
        outletRating: { doubleValue: 4.5 },
      },
    },
  });
  assert(aliceReview.status === 200, 'Registered user CAN publish one review per place');

  // User CANNOT publish review with mismatched reviewId (attempting second review under fake ID)
  const aliceSecondReviewMismatchedId = await request({
    method: 'PATCH',
    path: '/places/kopi-ruang/reviews/review_extra_999',
    token: userAlice,
    body: {
      fields: {
        userId: { stringValue: 'alice_uid' },
        placeId: { stringValue: 'kopi-ruang' },
        userName: { stringValue: 'Alice W' },
        rating: { doubleValue: 4.0 },
        comment: { stringValue: 'Review kedua yang tidak valid.' },
        createdAt: { timestampValue: reviewCreatedAt },
      },
    },
  });
  assert(
    aliceSecondReviewMismatchedId.status === 403,
    'User CANNOT publish second review with arbitrary reviewId (enforcing one review per place)'
  );

  // Bob CANNOT edit Alice's review
  const bobEditsAliceReview = await request({
    method: 'PATCH',
    path: '/places/kopi-ruang/reviews/alice_uid',
    token: userBob,
    body: {
      fields: {
        userId: { stringValue: 'alice_uid' },
        placeId: { stringValue: 'kopi-ruang' },
        rating: { doubleValue: 1.0 },
        comment: { stringValue: 'Hacked by Bob!' },
        createdAt: { timestampValue: reviewCreatedAt },
      },
    },
  });
  assert(bobEditsAliceReview.status === 403, 'User CANNOT edit another user review');

  // Invalid rating values are rejected: Rating > 5.0
  const invalidHighRating = await request({
    method: 'PATCH',
    path: '/places/kopi-ruang/reviews/bob_uid',
    token: userBob,
    body: {
      fields: {
        userId: { stringValue: 'bob_uid' },
        placeId: { stringValue: 'kopi-ruang' },
        rating: { doubleValue: 6.0 },
        comment: { stringValue: 'Rating di luar batas maksimum.' },
        createdAt: { timestampValue: reviewCreatedAt },
      },
    },
  });
  assert(invalidHighRating.status === 403, 'Rating value > 5.0 is REJECTED');

  // Invalid rating values are rejected: Rating < 1.0
  const invalidLowRating = await request({
    method: 'PATCH',
    path: '/places/kopi-ruang/reviews/bob_uid',
    token: userBob,
    body: {
      fields: {
        userId: { stringValue: 'bob_uid' },
        placeId: { stringValue: 'kopi-ruang' },
        rating: { doubleValue: 0.5 },
        comment: { stringValue: 'Rating di bawah batas minimum.' },
        createdAt: { timestampValue: reviewCreatedAt },
      },
    },
  });
  assert(invalidLowRating.status === 403, 'Rating value < 1.0 is REJECTED');

  // Invalid comment: too short (< 3 chars)
  const invalidShortComment = await request({
    method: 'PATCH',
    path: '/places/kopi-ruang/reviews/bob_uid',
    token: userBob,
    body: {
      fields: {
        userId: { stringValue: 'bob_uid' },
        placeId: { stringValue: 'kopi-ruang' },
        rating: { doubleValue: 4.0 },
        comment: { stringValue: 'ok' },
        createdAt: { timestampValue: reviewCreatedAt },
      },
    },
  });
  assert(invalidShortComment.status === 403, 'Comment with less than 3 characters is REJECTED');

  // Bob publishes valid review
  const bobValidReview = await request({
    method: 'PATCH',
    path: '/places/kopi-ruang/reviews/bob_uid',
    token: userBob,
    body: {
      fields: {
        userId: { stringValue: 'bob_uid' },
        placeId: { stringValue: 'kopi-ruang' },
        userName: { stringValue: 'Bob D' },
        rating: { doubleValue: 4.2 },
        comment: { stringValue: 'Tempat bagus, AC dingin, kopi mantap.' },
        createdAt: { timestampValue: reviewCreatedAt },
      },
    },
  });
  assert(bobValidReview.status === 200, 'Bob CAN publish valid review');

  // Identity/ownership immutability on update: Attempting to change userId
  const changeUserIdAttempt = await request({
    method: 'PATCH',
    path: '/places/kopi-ruang/reviews/bob_uid',
    token: userBob,
    body: {
      fields: {
        userId: { stringValue: 'charlie_uid' },
        placeId: { stringValue: 'kopi-ruang' },
        rating: { doubleValue: 4.2 },
        comment: { stringValue: 'Updated comment with changed userId' },
        createdAt: { timestampValue: reviewCreatedAt },
      },
    },
  });
  assert(changeUserIdAttempt.status === 403, 'Identity field userId CANNOT be changed on update');

  // Identity/ownership immutability on update: Attempting to change placeId
  const changePlaceIdAttempt = await request({
    method: 'PATCH',
    path: '/places/kopi-ruang/reviews/bob_uid',
    token: userBob,
    body: {
      fields: {
        userId: { stringValue: 'bob_uid' },
        placeId: { stringValue: 'other-place' },
        rating: { doubleValue: 4.2 },
        comment: { stringValue: 'Updated comment with changed placeId' },
        createdAt: { timestampValue: reviewCreatedAt },
      },
    },
  });
  assert(changePlaceIdAttempt.status === 403, 'Identity field placeId CANNOT be changed on update');

  // Identity/ownership immutability on update: Attempting to change createdAt
  const changeCreatedAtAttempt = await request({
    method: 'PATCH',
    path: '/places/kopi-ruang/reviews/bob_uid',
    token: userBob,
    body: {
      fields: {
        userId: { stringValue: 'bob_uid' },
        placeId: { stringValue: 'kopi-ruang' },
        rating: { doubleValue: 4.2 },
        comment: { stringValue: 'Updated comment with changed createdAt' },
        createdAt: { timestampValue: new Date(Date.now() - 100000).toISOString() },
      },
    },
  });
  assert(changeCreatedAtAttempt.status === 403, 'Identity field createdAt CANNOT be changed on update');

  // Forged review ownership: Alice publishes review claiming userId is bob_uid
  const forgedOwnershipReview = await request({
    method: 'PATCH',
    path: '/places/kopi-ruang/reviews/alice_uid',
    token: userAlice,
    body: {
      fields: {
        userId: { stringValue: 'bob_uid' },
        placeId: { stringValue: 'kopi-ruang' },
        userName: { stringValue: 'Alice Impersonating Bob' },
        rating: { doubleValue: 4.5 },
        comment: { stringValue: 'Attempting to forge ownership to another user' },
        createdAt: { timestampValue: reviewCreatedAt },
      },
    },
  });
  assert(forgedOwnershipReview.status === 403, 'Review with forged userId != auth.uid is REJECTED');

  // Invalid rating type: String instead of Number
  const stringRatingReview = await request({
    method: 'PATCH',
    path: '/places/kopi-ruang/reviews/alice_uid',
    token: userAlice,
    body: {
      fields: {
        userId: { stringValue: 'alice_uid' },
        placeId: { stringValue: 'kopi-ruang' },
        userName: { stringValue: 'Alice W' },
        rating: { stringValue: 'five' },
        comment: { stringValue: 'Review with invalid string rating' },
        createdAt: { timestampValue: reviewCreatedAt },
      },
    },
  });
  assert(stringRatingReview.status === 403, 'Review with non-numeric rating type is REJECTED');

  // Spoofed timestamp: createdAt sent as String instead of Timestamp
  const spoofedTimestampReview = await request({
    method: 'PATCH',
    path: '/places/kopi-ruang/reviews/alice_uid',
    token: userAlice,
    body: {
      fields: {
        userId: { stringValue: 'alice_uid' },
        placeId: { stringValue: 'kopi-ruang' },
        userName: { stringValue: 'Alice W' },
        rating: { doubleValue: 4.5 },
        comment: { stringValue: 'Review with string createdAt' },
        createdAt: { stringValue: '2026-10-15T00:00:00Z' },
      },
    },
  });
  assert(spoofedTimestampReview.status === 403, 'Review with spoofed non-timestamp createdAt is REJECTED');

  // priceValueRating outside 1-5: > 5.0 is REJECTED
  const highPriceRatingReview = await request({
    method: 'PATCH',
    path: '/places/kopi-ruang/reviews/alice_uid',
    token: userAlice,
    body: {
      fields: {
        userId: { stringValue: 'alice_uid' },
        placeId: { stringValue: 'kopi-ruang' },
        userName: { stringValue: 'Alice W' },
        rating: { doubleValue: 4.5 },
        comment: { stringValue: 'Review with priceValueRating too high' },
        priceValueRating: { doubleValue: 5.5 },
        createdAt: { timestampValue: reviewCreatedAt },
      },
    },
  });
  assert(highPriceRatingReview.status === 403, 'Sub-score priceValueRating > 5.0 is REJECTED');

  // priceValueRating outside 1-5: < 1.0 is REJECTED
  const lowPriceRatingReview = await request({
    method: 'PATCH',
    path: '/places/kopi-ruang/reviews/alice_uid',
    token: userAlice,
    body: {
      fields: {
        userId: { stringValue: 'alice_uid' },
        placeId: { stringValue: 'kopi-ruang' },
        userName: { stringValue: 'Alice W' },
        rating: { doubleValue: 4.5 },
        comment: { stringValue: 'Review with priceValueRating too low' },
        priceValueRating: { doubleValue: 0.5 },
        createdAt: { timestampValue: reviewCreatedAt },
      },
    },
  });
  assert(lowPriceRatingReview.status === 403, 'Sub-score priceValueRating < 1.0 is REJECTED');

  // Valid priceValueRating within 1-5 is ALLOWED
  const validPriceRatingReview = await request({
    method: 'PATCH',
    path: '/places/kopi-ruang/reviews/alice_uid',
    token: userAlice,
    body: {
      fields: {
        userId: { stringValue: 'alice_uid' },
        placeId: { stringValue: 'kopi-ruang' },
        userName: { stringValue: 'Alice W' },
        rating: { doubleValue: 4.5 },
        comment: { stringValue: 'Review with valid priceValueRating and all subscores' },
        priceValueRating: { doubleValue: 4.0 },
        wifiRating: { doubleValue: 4.5 },
        createdAt: { timestampValue: reviewCreatedAt },
      },
    },
  });
  assert(validPriceRatingReview.status === 200, 'Review with valid priceValueRating is ALLOWED');

  // Arbitrary / client-controlled privileged fields in review: isMockDemonstration is REJECTED
  const mockFieldReview = await request({
    method: 'PATCH',
    path: '/places/kopi-ruang/reviews/alice_uid',
    token: userAlice,
    body: {
      fields: {
        userId: { stringValue: 'alice_uid' },
        placeId: { stringValue: 'kopi-ruang' },
        userName: { stringValue: 'Alice W' },
        rating: { doubleValue: 4.5 },
        comment: { stringValue: 'Review with injected isMockDemonstration' },
        isMockDemonstration: { booleanValue: true },
        createdAt: { timestampValue: reviewCreatedAt },
      },
    },
  });
  assert(mockFieldReview.status === 403, 'Review with client-controlled isMockDemonstration is REJECTED');

  // Arbitrary / client-controlled privileged fields in review: isVerifiedPartner is REJECTED
  const partnerFieldReview = await request({
    method: 'PATCH',
    path: '/places/kopi-ruang/reviews/alice_uid',
    token: userAlice,
    body: {
      fields: {
        userId: { stringValue: 'alice_uid' },
        placeId: { stringValue: 'kopi-ruang' },
        userName: { stringValue: 'Alice W' },
        rating: { doubleValue: 4.5 },
        comment: { stringValue: 'Review with injected isVerifiedPartner' },
        isVerifiedPartner: { booleanValue: true },
        createdAt: { timestampValue: reviewCreatedAt },
      },
    },
  });
  assert(partnerFieldReview.status === 403, 'Review with client-controlled isVerifiedPartner is REJECTED');

  // Bob can successfully update his own review comment & rating
  const bobUpdatesOwnReview = await request({
    method: 'PATCH',
    path: '/places/kopi-ruang/reviews/bob_uid',
    token: userBob,
    body: {
      fields: {
        userId: { stringValue: 'bob_uid' },
        placeId: { stringValue: 'kopi-ruang' },
        userName: { stringValue: 'Bob D' },
        rating: { doubleValue: 4.7 },
        comment: { stringValue: 'Update: Setelah coba lagi, internet makin cepat!' },
        createdAt: { timestampValue: reviewCreatedAt },
      },
    },
  });
  assert(bobUpdatesOwnReview.status === 200, 'Owner CAN update own review comment and rating');

  // Bob can delete his own review
  const bobDeletesOwnReview = await request({
    method: 'DELETE',
    path: '/places/kopi-ruang/reviews/bob_uid',
    token: userBob,
  });
  assert(bobDeletesOwnReview.status === 200, 'Owner CAN delete own review');

  // ──────────────────────────────────────────────────────────────────────────
  // 5. Privacy & Sensitive Information Leak Prevention
  // ──────────────────────────────────────────────────────────────────────────
  console.log('\n5. Privacy Hardening (No Email / Phone in Public Reviews):');

  // Attempt to publish review containing 'email' field
  const reviewWithEmail = await request({
    method: 'PATCH',
    path: '/places/kopi-ruang/reviews/bob_uid',
    token: userBob,
    body: {
      fields: {
        userId: { stringValue: 'bob_uid' },
        placeId: { stringValue: 'kopi-ruang' },
        email: { stringValue: 'bob@private-domain.com' },
        rating: { doubleValue: 4.0 },
        comment: { stringValue: 'Leaking my email in review' },
        createdAt: { timestampValue: reviewCreatedAt },
      },
    },
  });
  assert(reviewWithEmail.status === 403, 'Review containing email field is strictly REJECTED');

  // Attempt to publish review containing 'userEmail' field
  const reviewWithUserEmail = await request({
    method: 'PATCH',
    path: '/places/kopi-ruang/reviews/bob_uid',
    token: userBob,
    body: {
      fields: {
        userId: { stringValue: 'bob_uid' },
        placeId: { stringValue: 'kopi-ruang' },
        userEmail: { stringValue: 'bob@private-domain.com' },
        rating: { doubleValue: 4.0 },
        comment: { stringValue: 'Leaking userEmail in review' },
        createdAt: { timestampValue: reviewCreatedAt },
      },
    },
  });
  assert(reviewWithUserEmail.status === 403, 'Review containing userEmail field is strictly REJECTED');

  // Attempt to publish review containing 'phoneNumber' field
  const reviewWithPhone = await request({
    method: 'PATCH',
    path: '/places/kopi-ruang/reviews/bob_uid',
    token: userBob,
    body: {
      fields: {
        userId: { stringValue: 'bob_uid' },
        placeId: { stringValue: 'kopi-ruang' },
        phoneNumber: { stringValue: '+628123456789' },
        rating: { doubleValue: 4.0 },
        comment: { stringValue: 'Leaking phoneNumber in review' },
        createdAt: { timestampValue: reviewCreatedAt },
      },
    },
  });
  assert(reviewWithPhone.status === 403, 'Review containing phoneNumber field is strictly REJECTED');

  // ──────────────────────────────────────────────────────────────────────────
  // 6. Admin and Partner Protection
  // ──────────────────────────────────────────────────────────────────────────
  console.log('\n6. Partner & Admin Collections Protection:');

  // Unauthorized write to /partners
  const unauthPartnerWrite = await request({
    method: 'PATCH',
    path: '/partners/partner_123',
    token: userAlice,
    body: {
      fields: { name: { stringValue: 'Fake Partner' } },
    },
  });
  assert(unauthPartnerWrite.status === 403, 'Non-admin write to /partners is DENIED');

  // Unauthorized write to /admin
  const unauthAdminWrite = await request({
    method: 'PATCH',
    path: '/admin/config',
    token: userAlice,
    body: {
      fields: { maintenanceMode: { booleanValue: true } },
    },
  });
  assert(unauthAdminWrite.status === 403, 'Non-admin write to /admin is DENIED');

  // Admin write to /admin is allowed
  const adminAllowedWrite = await request({
    method: 'PATCH',
    path: '/admin/config',
    token: adminUser,
    body: {
      fields: { maintenanceMode: { booleanValue: false } },
    },
  });
  assert(adminAllowedWrite.status === 200, 'Admin write to /admin is ALLOWED');

  // ──────────────────────────────────────────────────────────────────────────
  // 7. Geoapify Place Identity Compatibility & Hardening
  // ──────────────────────────────────────────────────────────────────────────
  console.log('\n7. Geoapify Place Identity Compatibility & Hardening:');

  const geoapifyKey = 'geoapify:5130b427435f3d5b40590a';

  // Direct client writes to /places/{geoapifyKey} are strictly denied
  const writeGeoapifyPlace = await request({
    method: 'PATCH',
    path: `/places/${geoapifyKey}`,
    token: userAlice,
    body: {
      fields: { studyScore: { doubleValue: 9.5 } },
    },
  });
  assert(writeGeoapifyPlace.status === 403, 'Direct client writes to Geoapify place document are DENIED');

  // Alice can bookmark a Geoapify place
  const aliceSavesGeoapify = await request({
    method: 'PATCH',
    path: `/users/alice_uid/saved_places/${geoapifyKey}`,
    token: userAlice,
    body: {
      fields: {
        placeId: { stringValue: geoapifyKey },
        name: { stringValue: 'Geoapify Cafe Test' },
        savedAt: { timestampValue: nowIso },
      },
    },
  });
  assert(aliceSavesGeoapify.status === 200, 'Owner can save Geoapify place bookmark under own UID');

  // Bob cannot read Alice's Geoapify bookmark
  const bobReadsAliceGeoapify = await request({
    method: 'GET',
    path: `/users/alice_uid/saved_places/${geoapifyKey}`,
    token: userBob,
  });
  assert(bobReadsAliceGeoapify.status === 403, 'Another user CANNOT read private Geoapify bookmark');

  // Anonymous guest cannot publish review for Geoapify place
  const guestGeoapifyReview = await request({
    method: 'PATCH',
    path: `/places/${geoapifyKey}/reviews/guest_charlie_uid`,
    token: guestUser,
    body: {
      fields: {
        userId: { stringValue: 'guest_charlie_uid' },
        placeId: { stringValue: geoapifyKey },
        rating: { doubleValue: 4.5 },
        comment: { stringValue: 'Guest attempt on Geoapify place' },
        createdAt: { timestampValue: reviewCreatedAt },
      },
    },
  });
  assert(guestGeoapifyReview.status === 403, 'Anonymous guest CANNOT publish review on Geoapify place');

  // Registered user CAN publish review for Geoapify place
  const aliceGeoapifyReview = await request({
    method: 'PATCH',
    path: `/places/${geoapifyKey}/reviews/alice_uid`,
    token: userAlice,
    body: {
      fields: {
        userId: { stringValue: 'alice_uid' },
        placeId: { stringValue: geoapifyKey },
        userName: { stringValue: 'Alice W' },
        rating: { doubleValue: 4.9 },
        comment: { stringValue: 'Tempat Geoapify ini sangat tenang dan nyaman untuk nugas!' },
        createdAt: { timestampValue: reviewCreatedAt },
      },
    },
  });
  assert(aliceGeoapifyReview.status === 200, 'Registered user CAN publish review on Geoapify place');

  // User cannot publish review if placeId body does not match Geoapify path key
  const aliceMismatchedGeoapifyReview = await request({
    method: 'PATCH',
    path: `/places/${geoapifyKey}/reviews/alice_uid`,
    token: userAlice,
    body: {
      fields: {
        userId: { stringValue: 'alice_uid' },
        placeId: { stringValue: 'different-place-id' },
        rating: { doubleValue: 4.9 },
        comment: { stringValue: 'Mismatched placeId body' },
        createdAt: { timestampValue: reviewCreatedAt },
      },
    },
  });
  assert(aliceMismatchedGeoapifyReview.status === 403, 'Review with mismatched placeId body vs Geoapify path is REJECTED');

  console.log('\n============================================================');
  console.log(`TEST SUMMARY: ${passedTests} / ${totalTests} assertions passed!`);
  console.log('============================================================\n');

  if (passedTests !== totalTests) {
    process.exit(1);
  }
}

runTests().catch((e) => {
  console.error('Fatal error during security rules validation:', e);
  process.exit(1);
});
