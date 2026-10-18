import {createEncryptedBackup, verifyEncryptedBackup} from './encrypted-backup.js';

let key;
try {
  const [operation, source, destination, ...extra] = process.argv.slice(2);
  if (extra.length || !source || !['create', 'verify'].includes(operation)
    || (operation === 'create' ? !destination : destination !== undefined)) {
    throw new Error('usage: encrypted-backup-cli.js create SOURCE DESTINATION | verify BACKUP');
  }
  const secret = process.env.KRAS_ACCOUNT_BACKUP_KEY_HEX;
  if (typeof secret !== 'string' || !/^[a-f0-9]{64}$/i.test(secret)) {
    throw new Error('invalid_backup_key');
  }
  key = Buffer.from(secret, 'hex');
  const result = operation === 'create'
    ? await createEncryptedBackup(source, destination, key)
    : await verifyEncryptedBackup(source, key);
  console.log(JSON.stringify(result));
} catch (error) {
  // Native filesystem errors can include private paths; print only the code.
  console.error(error.code ? `backup_operation_failed: ${error.code}` : error.message);
  process.exitCode = 1;
} finally {
  key?.fill(0);
}
