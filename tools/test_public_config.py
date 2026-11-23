import base64
import json
import unittest
from prepare_public_config import public_config

class PublicConfigTests(unittest.TestCase):
    def test_only_allowlisted_public_fields_are_emitted(self):
        result = public_config('SUPABASE_URL=https://example.test\nSUPABASE_ANON_KEY=sb_publishable_fixture\n'
            'WAHA_API_KEY=private-fixture\nONESIGNAL_REST_API_KEY=private-fixture\nOTHER_SECRET=private-fixture')
        self.assertEqual(set(result), {'SUPABASE_URL', 'SUPABASE_ANON_KEY', 'APP_ENVIRONMENT'})
        self.assertNotIn('private-fixture', json.dumps(result))

    def test_private_supabase_keys_are_rejected(self):
        payload = base64.urlsafe_b64encode(json.dumps({'role': 'service_role'}).encode()).decode().rstrip('=')
        for key in ['sb_secret_fixture', 'header.' + payload + '.signature']:
            with self.assertRaises(ValueError):
                public_config('SUPABASE_URL=https://example.test\nSUPABASE_ANON_KEY=' + key)

if __name__ == '__main__':
    unittest.main()
