from django.contrib.auth import get_user_model
from django.test import TestCase


class UserModelTests(TestCase):
    def test_create_user(self):
        user = get_user_model().objects.create_user(
            name="Alice Example",
            email="ALICE@example.com",
            password="secretPassword123",
        )

        self.assertEqual(user.email, "ALICE@example.com")
        self.assertTrue(user.check_password("secretPassword123"))
        self.assertNotEqual(user.password, "secretPassword123")
        self.assertFalse(user.is_staff)
        self.assertFalse(user.is_superuser)

    def test_email_is_normalized(self):
        user = get_user_model().objects.create_user(
            name="Bob Example",
            email="BOB@EXAMPLE.COM",
            password="secretPassword123",
        )

        self.assertEqual(user.email, "BOB@example.com")

    def test_create_superuser(self):
        admin_user = get_user_model().objects.create_superuser(
            name="Admin User",
            email="admin@example.com",
            password="adminPassword123",
        )

        self.assertTrue(admin_user.is_staff)
        self.assertTrue(admin_user.is_superuser)
        self.assertTrue(admin_user.check_password("adminPassword123"))
