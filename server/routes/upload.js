const router = require('express').Router();
const multer = require('multer');
const { requireAuth } = require('../middleware/auth');

// Use memory storage — upload buffer directly to Cloudinary v2
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 50 * 1024 * 1024 } });

// POST /api/upload  — single file upload to Cloudinary
router.post('/', requireAuth, upload.single('file'), async (req, res) => {
  if (!process.env.CLOUDINARY_CLOUD_NAME || !process.env.CLOUDINARY_API_KEY || !process.env.CLOUDINARY_API_SECRET) {
    return res.status(503).json({
      error: 'Cloudinary not configured. Set CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET secrets.',
    });
  }

  if (!req.file) return res.status(400).json({ error: 'No file provided' });

  try {
    const { v2: cloudinary } = require('cloudinary');
    cloudinary.config({
      cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
      api_key:    process.env.CLOUDINARY_API_KEY,
      api_secret: process.env.CLOUDINARY_API_SECRET,
    });

    const mime = req.file.mimetype;
    const resourceType = mime.startsWith('video/') || mime.startsWith('audio/')
      ? 'video'
      : mime.startsWith('image/')
        ? 'image'
        : 'raw';

    // Upload buffer via upload_stream
    const result = await new Promise((resolve, reject) => {
      const stream = cloudinary.uploader.upload_stream(
        {
          folder: 'whatsapp-clone',
          resource_type: resourceType,
          public_id: `${Date.now()}-${req.file.originalname.replace(/[^a-zA-Z0-9.-]/g, '_')}`,
        },
        (error, result) => (error ? reject(error) : resolve(result))
      );
      stream.end(req.file.buffer);
    });

    res.json({
      url:      result.secure_url,
      publicId: result.public_id,
      mimeType: req.file.mimetype,
      size:     req.file.size,
    });
  } catch (err) {
    console.error('Cloudinary upload error:', err);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
