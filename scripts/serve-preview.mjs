import { createApplication } from './server.mjs';

const port = Number(process.env.PORT || 4173);
createApplication().listen(port, '0.0.0.0', () => console.log(`Asterion preview: http://localhost:${port}`));
