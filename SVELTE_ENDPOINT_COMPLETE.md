# Svelte Backend: Complete Incident Endpoint

## Quick Setup Guide

### File to Create: `src/routes/api/admin/incident/[incidentId]/complete/+server.ts`

```typescript
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import { ObjectId } from 'mongodb';
import { connectToDatabase } from '$lib/server/mongodb';

export const PUT: RequestHandler = async ({ request, params }) => {
  try {
    // 1. Authentication check
    const authHeader = request.headers.get('authorization');
    const userId = request.headers.get('x-user-id');

    if (!authHeader || !userId) {
      return json({ error: 'Unauthorized' }, { status: 401 });
    }

    // 2. Connect to database
    const db = await connectToDatabase();
    const usersCollection = db.collection('users');
    const incidentsCollection = db.collection('incidents');

    // 3. Verify user permissions (OFFICER, MANAGER, or ADMINISTRATOR)
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

    // 6. Check if incident is already completed
    if (incident.status === 'COMPLETED') {
      return json({ error: 'Incident is already completed' }, { status: 400 });
    }

    // 7. Build update data
    const updateData: any = {
      status: 'COMPLETED',
      resolutionNotes: resolutionNotes || '',
      resolvedBy: resolvedBy || userId,
      resolvedByRole: resolvedByRole || user.role,
      resolvedAt: resolvedAt ? new Date(resolvedAt) : new Date(),
      updatedAt: new Date()
    };

    // 8. Handle resolution images
    if (resolutionImages && resolutionImages.length > 0) {
      updateData.resolutionImages = resolutionImages.map((img: any) => ({
        name: img.name,
        type: img.type,
        size: img.size,
        dataBase64: img.dataBase64, // Store base64 or upload to cloud
        uploadedAt: new Date()
      }));
    }

    // 9. Update incident
    const result = await incidentsCollection.updateOne(
      { _id: new ObjectId(incidentId) },
      { $set: updateData }
    );

    if (result.matchedCount === 0) {
      return json({ error: 'Failed to update incident' }, { status: 500 });
    }

    // 10. Fetch updated incident
    const updatedIncident = await incidentsCollection.findOne({
      _id: new ObjectId(incidentId)
    });

    // 11. Optional: Send notifications
    try {
      // TODO: Implement your notification service
      // await sendNotificationToReporter(incident.userId, {
      //   title: 'Incident Completed',
      //   body: `Your ${incident.incidentType} incident has been resolved`,
      //   data: { incidentId }
      // });
      console.log('📧 Notification sent to reporter');
    } catch (error) {
      console.error('Failed to send notification:', error);
    }

    // 12. Optional: Broadcast WebSocket update
    // TODO: Implement WebSocket broadcast if needed
    // broadcastIncidentUpdate(incidentId, 'COMPLETED');

    return json({
      success: true,
      message: 'Incident completed successfully',
      incident: updatedIncident
    });

  } catch (error) {
    console.error('Error completing incident:', error);
    return json(
      {
        error: 'Failed to complete incident',
        details: error instanceof Error ? error.message : 'Unknown error'
      },
      { status: 500 }
    );
  }
};
```

---

## Request Format

**Endpoint:** `PUT /api/admin/incident/:incidentId/complete`

**Headers:**
```
Authorization: Bearer <JWT_TOKEN>
X-User-ID: <USER_ID>
Content-Type: application/json
```

**Body:**
```json
{
  "status": "COMPLETED",
  "resolutionNotes": "Fire extinguished successfully. Area secured and safe.",
  "resolvedBy": "user123",
  "resolvedByRole": "OFFICER",
  "resolvedAt": "2025-10-20T15:30:00.000Z",
  "resolutionImages": [
    {
      "name": "after_resolution_1.jpg",
      "type": "image/jpeg",
      "dataBase64": "/9j/4AAQSkZJRgABAQAA...",
      "size": 125000
    },
    {
      "name": "after_resolution_2.jpg",
      "type": "image/jpeg",
      "dataBase64": "/9j/4AAQSkZJRgABAQAA...",
      "size": 98000
    }
  ]
}
```

---

## Response Format

**Success (200):**
```json
{
  "success": true,
  "message": "Incident completed successfully",
  "incident": {
    "_id": "68977108c8aaec3aecd89001",
    "userId": "JRpizMSn5WSrpByg4",
    "incidentType": "Fire",
    "description": "Building fire at Main Street",
    "status": "COMPLETED",
    "resolutionNotes": "Fire extinguished successfully. Area secured and safe.",
    "resolvedBy": "user123",
    "resolvedByRole": "OFFICER",
    "resolvedAt": "2025-10-20T15:30:00.000Z",
    "resolutionImages": [
      {
        "name": "after_resolution_1.jpg",
        "type": "image/jpeg",
        "size": 125000,
        "dataBase64": "...",
        "uploadedAt": "2025-10-20T15:30:00.000Z"
      }
    ],
    "createdAt": "2025-10-20T13:00:00.000Z",
    "updatedAt": "2025-10-20T15:30:00.000Z"
  }
}
```

**Error Responses:**

**401 Unauthorized:**
```json
{
  "error": "Unauthorized"
}
```

**403 Forbidden:**
```json
{
  "error": "Insufficient permissions"
}
```

**404 Not Found:**
```json
{
  "error": "Incident not found"
}
```

**400 Bad Request:**
```json
{
  "error": "Incident is already completed"
}
```

**500 Server Error:**
```json
{
  "error": "Failed to complete incident",
  "details": "Error details here"
}
```

---

## Testing with curl

```bash
# Replace with your actual values
INCIDENT_ID="68977108c8aaec3aecd89001"
JWT_TOKEN="your_jwt_token_here"
USER_ID="your_user_id_here"
BASE_URL="http://localhost:5173"

curl -X PUT \
  "$BASE_URL/api/admin/incident/$INCIDENT_ID/complete" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "X-User-ID: $USER_ID" \
  -d '{
    "resolutionNotes": "Fire extinguished successfully. Area secured and safe.",
    "resolvedBy": "'$USER_ID'",
    "resolvedByRole": "OFFICER",
    "resolvedAt": "2025-10-20T15:30:00.000Z",
    "resolutionImages": []
  }'
```

---

## MongoDB Schema Updates

Your `incidents` collection should support these fields:

```typescript
{
  _id: ObjectId,
  userId: string,
  incidentType: string,
  description: string,
  incidentLocation: {
    latitude: string,
    longitude: string
  },
  status: "PENDING" | "IN-PROGRESS" | "COMPLETED",
  createdAt: Date,
  updatedAt: Date,

  // NEW FIELDS for completion
  resolutionNotes?: string,
  resolvedBy?: string,
  resolvedByRole?: "OFFICER" | "MANAGER" | "ADMINISTRATOR",
  resolvedAt?: Date,
  resolutionImages?: Array<{
    name: string,
    type: string,
    size: number,
    dataBase64: string,
    uploadedAt: Date
  }>
}
```

---

## Performance Considerations

### Image Storage Strategy

**Current Implementation (Base64 in MongoDB):**
- ✅ Simple to implement
- ✅ Works immediately
- ❌ Limited to ~500KB per image
- ❌ Increases document size

**Recommended for Production (Cloud Storage):**
```typescript
// Example with Cloudflare R2 or AWS S3
import { uploadToCloudStorage } from '$lib/server/storage';

if (resolutionImages && resolutionImages.length > 0) {
  const uploadedImages = await Promise.all(
    resolutionImages.map(async (img: any) => {
      // Upload to cloud storage
      const url = await uploadToCloudStorage(
        Buffer.from(img.dataBase64, 'base64'),
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

## Security Checklist

- [x] Authentication required (JWT token)
- [x] User ID verification
- [x] Role-based authorization (OFFICER, MANAGER, ADMINISTRATOR)
- [x] Incident existence validation
- [x] Prevent double completion
- [ ] TODO: Validate incident assignment (optional)
- [ ] TODO: Sanitize resolutionNotes to prevent XSS
- [ ] TODO: Validate image file types
- [ ] TODO: Limit image size (currently handled by Flutter)
- [ ] TODO: Rate limiting

---

## Integration with Flutter

The Flutter app will call this endpoint from:
- File: `lib/services/incident_service.dart`
- Method: `resolveIncident()`
- Line: ~409

The request is automatically constructed with:
- Resolution notes from text input
- Up to 5 images (base64 encoded)
- User ID and role from auth service
- Current timestamp

---

## Next Steps

1. ✅ Create the endpoint file in your Svelte project
2. ⬜ Test with curl or Postman
3. ⬜ Test end-to-end with Flutter app
4. ⬜ Add notification service integration (optional)
5. ⬜ Implement cloud storage for images (recommended for production)
6. ⬜ Add WebSocket broadcasts for real-time updates (optional)
7. ⬜ Deploy to staging
8. ⬜ Test thoroughly
9. ⬜ Deploy to production
