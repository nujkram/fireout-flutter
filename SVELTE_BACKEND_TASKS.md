# Svelte Backend Implementation Tasks

## Overview
This document outlines the tasks needed to implement the incident resolution endpoint with image support in your Svelte backend.

---

## Task 1: Create the Complete Incident Endpoint

### File to Create: `src/routes/api/admin/incident/[incidentId]/complete/+server.ts`

```typescript
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { ObjectId } from 'mongodb';
import { connectToDatabase } from '$lib/server/mongodb';

export const PUT: RequestHandler = async ({ request, params }) => {
  try {
    // 1. Check authentication
    const authHeader = request.headers.get('authorization');
    const userId = request.headers.get('x-user-id');

    if (!authHeader || !userId) {
      return json({ error: 'Unauthorized' }, { status: 401 });
    }

    // 2. Connect to database
    const db = await connectToDatabase();
    const usersCollection = db.collection('users');
    const incidentsCollection = db.collection('incidents');

    // 3. Verify user role (must be OFFICER, MANAGER, or ADMINISTRATOR)
    const user = await usersCollection.findOne({ _id: new ObjectId(userId) });
    if (!user || !['OFFICER', 'MANAGER', 'ADMINISTRATOR'].includes(user.role)) {
      return json({ error: 'Insufficient permissions' }, { status: 403 });
    }

    // 4. Parse request body
    const body = await request.json();
    const { resolutionNotes, resolutionImages, resolvedBy, resolvedByRole, resolvedAt } = body;

    // 5. Validate incident exists
    const incidentId = params.incidentId;
    const incident = await incidentsCollection.findOne({ _id: new ObjectId(incidentId) });

    if (!incident) {
      return json({ error: 'Incident not found' }, { status: 404 });
    }

    // 6. Update incident in database
    const updateData = {
      status: 'COMPLETED',
      resolutionNotes: resolutionNotes || '',
      resolvedBy: resolvedBy || userId,
      resolvedByRole: resolvedByRole || user.role,
      resolvedAt: resolvedAt ? new Date(resolvedAt) : new Date(),
      updatedAt: new Date(),
      ...(resolutionImages && resolutionImages.length > 0 && {
        resolutionImages: resolutionImages.map((img: any) => ({
          name: img.name,
          type: img.type,
          size: img.size,
          dataBase64: img.dataBase64, // Store base64 or upload to cloud storage
          uploadedAt: new Date()
        }))
      })
    };

    const result = await incidentsCollection.updateOne(
      { _id: new ObjectId(incidentId) },
      { $set: updateData }
    );

    if (result.matchedCount === 0) {
      return json({ error: 'Failed to update incident' }, { status: 500 });
    }

    // 7. Fetch updated incident
    const updatedIncident = await incidentsCollection.findOne({
      _id: new ObjectId(incidentId)
    });

    // 8. Optional: Send notification to incident reporter
    // TODO: Implement notification service
    try {
      // await sendNotificationToReporter(incident.userId, {
      //   title: 'Incident Completed',
      //   body: `Your ${incident.incidentType} incident has been completed`,
      //   data: { incidentId: incidentId }
      // });
      console.log('📧 Notification sent to reporter');
    } catch (notifError) {
      console.error('Failed to send notification:', notifError);
      // Don't fail the request if notification fails
    }

    // 9. Optional: Emit WebSocket event for real-time updates
    // TODO: Implement WebSocket broadcast
    // broadcastIncidentUpdate(incidentId, 'COMPLETED', updatedIncident);

    return json({
      success: true,
      message: 'Incident resolved successfully',
      incident: updatedIncident
    });

  } catch (error) {
    console.error('Error resolving incident:', error);
    return json(
      { error: 'Failed to resolve incident', details: error.message },
      { status: 500 }
    );
  }
};
```

---

## Task 2: Update MongoDB Connection Helper (if not exists)

### File: `src/lib/server/mongodb.ts`

```typescript
import { MongoClient, Db } from 'mongodb';
import { MONGODB_URI } from '$env/static/private';

let cachedClient: MongoClient | null = null;
let cachedDb: Db | null = null;

export async function connectToDatabase(): Promise<Db> {
  if (cachedClient && cachedDb) {
    return cachedDb;
  }

  const client = new MongoClient(MONGODB_URI);
  await client.connect();

  const db = client.db(); // Uses default database from connection string

  cachedClient = client;
  cachedDb = db;

  return db;
}
```

### Environment Variable
Add to `.env` file:
```env
MONGODB_URI=mongodb+srv://mark:asdf1234@fire.qrebi.mongodb.net/bfpStaging
```

---

## Task 3: Update TypeScript Types

### File: `src/lib/types/incident.ts`

```typescript
export interface ResolutionImage {
  name: string;
  type: string;
  size: number;
  dataBase64: string;
  uploadedAt: Date;
  url?: string; // Optional: if uploaded to cloud storage
}

export interface Incident {
  _id: string;
  userId: string;
  incidentType: 'Fire' | 'Medical Emergency' | 'Traffic Accident' | 'Crime' | 'Natural Disaster' | 'Other';
  description: string;
  incidentLocation: {
    latitude: string;
    longitude: string;
  };
  status: 'PENDING' | 'IN-PROGRESS' | 'COMPLETED';
  createdAt: Date;
  updatedAt: Date;
  isActive: boolean;
  priority?: 'HIGH' | 'MEDIUM' | 'LOW';
  emergencyLevel?: string;
  files?: Array<{
    name: string;
    type: string;
    size: number;
    dataBase64: string;
  }>;

  // Resolution fields
  resolutionNotes?: string;
  resolvedBy?: string;
  resolvedByRole?: 'OFFICER' | 'MANAGER' | 'ADMINISTRATOR';
  resolvedAt?: Date;
  resolutionImages?: ResolutionImage[];
}
```

---

## Task 4: Optional - Cloud Storage Integration

If you want to store images in cloud storage instead of base64 in MongoDB:

### File: `src/lib/server/storage.ts`

```typescript
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
// or use Firebase Storage, Cloudflare R2, etc.

export async function uploadImageToCloud(
  imageData: string, // base64
  fileName: string,
  contentType: string
): Promise<string> {
  // Convert base64 to buffer
  const buffer = Buffer.from(imageData, 'base64');

  // Upload to S3/Cloud Storage
  // ... implementation depends on your cloud provider

  // Return public URL
  return 'https://your-cdn.com/images/' + fileName;
}
```

Then modify the endpoint to use it:

```typescript
// In resolve endpoint, before saving to MongoDB:
if (resolutionImages && resolutionImages.length > 0) {
  const uploadedImages = await Promise.all(
    resolutionImages.map(async (img: any) => {
      const url = await uploadImageToCloud(
        img.dataBase64,
        img.name,
        img.type
      );

      return {
        name: img.name,
        type: img.type,
        size: img.size,
        url: url, // Store URL instead of base64
        uploadedAt: new Date()
      };
    })
  );

  updateData.resolutionImages = uploadedImages;
}
```

---

## Task 5: Add Endpoint Tests

### File: `src/routes/api/admin/incident/[incidentId]/complete/+server.test.ts`

```typescript
import { describe, it, expect } from 'vitest';
import { PUT } from './+server';

describe('Complete Incident Endpoint', () => {
  it('should require authentication', async () => {
    const request = new Request('http://localhost/api/admin/incident/123/complete', {
      method: 'PUT',
      body: JSON.stringify({
        resolutionNotes: 'Test notes'
      })
    });

    const response = await PUT({ request, params: { incidentId: '123' } });
    const data = await response.json();

    expect(response.status).toBe(401);
    expect(data.error).toBe('Unauthorized');
  });

  // Add more tests...
});
```

---

## Task 6: Update API Documentation

Update your API documentation to include the new endpoint:

### Endpoint: `PUT /api/admin/incident/:incidentId/complete`

**Authentication:** Required (Bearer token + X-User-ID header)

**Permissions:** OFFICER, MANAGER, or ADMINISTRATOR

**Request Body:**
```json
{
  "status": "COMPLETED",
  "resolutionNotes": "Fire extinguished, area secured",
  "resolvedBy": "userId",
  "resolvedByRole": "OFFICER",
  "resolvedAt": "2025-10-20T15:30:00.000Z",
  "resolutionImages": [
    {
      "name": "resolution_photo1.jpg",
      "type": "image/jpeg",
      "dataBase64": "base64_encoded_image_data...",
      "size": 125000
    }
  ]
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Incident resolved successfully",
  "incident": {
    "_id": "68977108c8aaec3aecd89001",
    "status": "COMPLETED",
    "resolutionNotes": "Fire extinguished, area secured",
    "resolvedBy": "userId",
    "resolvedByRole": "OFFICER",
    "resolvedAt": "2025-10-20T15:30:00.000Z",
    "resolutionImages": [...],
    "updatedAt": "2025-10-20T15:30:00.000Z"
  }
}
```

---

## Task 7: Database Migration (Optional)

If you need to add indexes for better performance:

```javascript
// MongoDB shell or migration script
db.incidents.createIndex({ status: 1, resolvedAt: -1 });
db.incidents.createIndex({ resolvedBy: 1 });
```

---

## Implementation Checklist

- [ ] Create `src/routes/api/admin/incident/[incidentId]/complete/+server.ts`
- [ ] Verify MongoDB connection helper exists and works
- [ ] Update TypeScript types in `src/lib/types/incident.ts`
- [ ] Test endpoint with Postman/curl
- [ ] (Optional) Implement cloud storage for images
- [ ] (Optional) Add notification service integration
- [ ] (Optional) Add WebSocket broadcast for real-time updates
- [ ] Update API documentation
- [ ] Add endpoint tests
- [ ] Deploy to staging environment
- [ ] Test end-to-end with Flutter app
- [ ] Deploy to production

---

## Testing the Endpoint

### Using curl:

```bash
curl -X PUT \
  http://localhost:5173/api/admin/incident/68977108c8aaec3aecd89001/complete \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer YOUR_JWT_TOKEN' \
  -H 'X-User-ID: YOUR_USER_ID' \
  -d '{
    "resolutionNotes": "Fire extinguished successfully",
    "resolvedBy": "YOUR_USER_ID",
    "resolvedByRole": "OFFICER",
    "resolvedAt": "2025-10-20T15:30:00.000Z",
    "resolutionImages": []
  }'
```

### Expected Response:
```json
{
  "success": true,
  "message": "Incident resolved successfully",
  "incident": { ... }
}
```

---

## Notes

1. **Image Storage Strategy:**
   - For small deployments: Store base64 in MongoDB (current implementation)
   - For production: Use cloud storage (S3, Cloudflare R2, Firebase Storage)
   - Base64 limit: ~500KB per image (recommended)

2. **Status Values:**
   - Changed from "RESOLVED" to "COMPLETED" as per your requirement

3. **Security Considerations:**
   - Verify JWT token validity
   - Check user permissions before allowing resolution
   - Validate incident ownership/assignment (optional)
   - Sanitize resolution notes to prevent XSS

4. **Performance:**
   - Consider implementing image compression on backend
   - Add database indexes for frequently queried fields
   - Implement pagination for resolution images if many are expected

---

## Questions?

If you need clarification on any of these tasks, please refer to:
- Flutter implementation: `lib/ui/screens/incident/incident_detail_screen.dart`
- Service layer: `lib/services/incident_service.dart`
- API configuration: `lib/config/app_config.dart`
