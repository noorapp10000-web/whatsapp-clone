const router = require('express').Router();
const multer = require('multer');
const { requireAuth } = require('../middleware/auth');

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 50 * 1024 * 1024 } });

const getCloudinary = () => {
  const { v2: cloudinary } = require('cloudinary');
  cloudinary.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    api_key:    process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET,
  });
  return cloudinary;
};

const resourceType = (mime = '') =>
  mime.startsWith('video/') || mime.startsWith('audio/') ? 'video'
  : mime.startsWith('image/') ? 'image' : 'raw';

router.post('/', requireAuth, upload.single('file'), async (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'No file provided' });
  try {
    const cloudinary = getCloudinary();
    const result = await new Promise((resolve, reject) => {
      const stream = cloudinary.uploader.upload_stream(
        { folder: 'whatsapp-clone', resource_type: resourceType(req.file.mimetype),
          public_id: `${Date.now()}-${req.file.originalname.replace(/[^a-zA-Z0-9.-]/g, '_')}` },
        (error, result) => error ? reject(error) : resolve(result)
      );
      stream.end(req.file.buffer);
    });
    res.json({ url: result.secure_url, publicId: result.public_id, mimeType: req.file.mimetype, size: req.file.size });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/base64', requireAuth, async (req, res) => {
  const { base64, mimeType, fileName } = req.body;
  if (!base64) return res.status(400).json({ error: 'base64 required' });
  try {
    const cloudinary = getCloudinary();
    const result = await cloudinary.uploader.upload(base64, {
      folder: 'whatsapp-clone', resource_type: resourceType(mimeType),
      public_id: `${Date.now()}-${(fileName || 'file').replace(/[^a-zA-Z0-9.-]/g, '_')}`,
    });
    res.json({ url: result.secure_url, publicId: result.public_id, mimeType, size: result.bytes });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
