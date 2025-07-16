from django.db import models
from django.contrib.auth.models import AbstractUser
from django.db.models.signals import post_save
from django.dispatch import receiver
from django.db.models import F # Import F for atomic updates
from django.db import transaction
class Category(models.Model):
    name = models.CharField(max_length=100)

    def __str__(self):
        return self.name
    class Meta:
        verbose_name_plural = "Categories"

class Furniture(models.Model):
    category = models.ForeignKey(Category, on_delete=models.CASCADE)
    name = models.CharField(max_length=200)
    item_code = models.CharField(max_length=20, unique=True)
    description= models.TextField()
    price = models.DecimalField(max_digits=8 , decimal_places=2)
    image = models.ImageField(upload_to='furniture_images/', blank=True, null=True)
    featured = models.BooleanField(default=False)
    def __str__(self):
        return self.name

class CustomUser(AbstractUser):
    phone = models.CharField(max_length=15, blank=True, null=True)
    nrc = models.CharField(max_length=30, blank=True)
    dob = models.DateField(null=True, blank=True)
    c_code = models.CharField(max_length=20, unique=True, blank=True)
    createdby = models.CharField(max_length=20, default='website')
    amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0.00
    )
    member_level_choices = [
        ('Bronze', 'Bronze'),
        ('Silver', 'Silver'),
        ('Gold', 'Gold'),
        ('Platinum', 'Platinum'),
        ('Diamond', 'Diamond'),
        ('Legend','Legend'),
    ]
    member_level = models.CharField(
        max_length=10,
        choices=member_level_choices,
        default='Bronze'
    )

    def save(self, *args, **kwargs):
        if not self.c_code:
            last_user = CustomUser.objects.filter(c_code__startswith='MC-').order_by('-c_code').first()
            if last_user and last_user.c_code:
                try:
                    last_number = int(last_user.c_code.split('-')[1])
                except (IndexError, ValueError):
                    last_number = 0
            else:
                last_number = 0
            new_number = last_number + 1
            self.c_code = f'MC-{new_number:05d}'  # e.g., MC-00001

        super().save(*args, **kwargs)
    def update_membership_level(self):
        if self.amount >= 100000:
            self.member_level = 'Legend'
        elif self.amount >= 50000:
            self.member_level = 'Diamond'
        elif self.amount >= 20000:
            self.member_level = 'Platinum'
        elif self.amount >= 10000:
            self.member_level = 'Gold'
        elif self.amount >= 5000:
            self.member_level = 'Silver'
        else:
            self.member_level = 'Bronze'
    def add_amount_and_update_level(self, amount):
        self.amount += amount
        old_level = self.member_level
        self.update_membership_level()

        if old_level != self.member_level:
            UserMembershipLog.objects.create(
                user=self,
                old_level=old_level,
                new_level=self.member_level
            )

        self.save(update_fields=['amount', 'member_level'])
    def __str__(self):
        return self.username
class Order(models.Model):
    user = models.ForeignKey(CustomUser, on_delete=models.SET_NULL, null=True, blank=True, related_name='orders')
    order_number = models.CharField(max_length=20, unique=True, blank=True, null=True) # New field for order number
    customer_name = models.CharField(max_length=100)
    customer_address = models.TextField()
    customer_phone = models.CharField(max_length=20)
    STATUS_CHOICES = [
        ('Pending', 'Pending'),
        ('Processing', 'Processing'),
        ('Shipped', 'Shipped'),
        ('Delivered', 'Delivered'),
        ('Cancelled', 'Cancelled'),
    ]
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='Pending')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    total_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    PAYMENT_CHOICES = [
        ('Pending', 'Pending'),
        ('Completed', 'Completed'),
        ('Failed', 'Failed'),
    ]
    payment_status = models.CharField(max_length=20, choices=PAYMENT_CHOICES, default='Pending')
    payment_method = models.CharField(max_length=50, blank=True, null=True)

    def __str__(self):
        return f"Order #{self.order_number or self.id} by {self.customer_name}"

    def calculate_total_amount(self):
        return sum(item.get_total() for item in self.items.all())

    def save(self, *args, **kwargs):

        if not self.pk: # This block runs ONLY when the object is being created for the first time
            if not self.order_number: # Only generate if not already set (e.g., manually set by admin)
                with transaction.atomic(): # Ensures thread-safe increment
                    last_order = Order.objects.select_for_update().order_by('-id').first()
                    next_num = 3000001 # Default starting number

                    if last_order and last_order.order_number and last_order.order_number.startswith('SO-'):
                        try:
                            # Extract the numeric part (e.g., "3000001" from "SO-3000001")
                            last_num_str = last_order.order_number.split('-')[1]
                            last_num = int(last_num_str)
                            next_num = last_num + 1
                        except (ValueError, IndexError):
                            # Fallback if the existing order number is malformed
                            # This ensures we always start from a known good point if an error occurs
                            next_num = 3000001

                    # Format the number with leading zeros (e.g., 1 -> 0000001)
                    self.order_number = f"SO-{next_num:07d}"

        super().save(*args, **kwargs)

class OrderItem(models.Model):
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='items')
    furniture = models.ForeignKey(Furniture, on_delete=models.PROTECT)
    quantity = models.PositiveIntegerField(default=1)
    price_at_purchase = models.DecimalField(max_digits=8, decimal_places=2)

    def get_total(self):
        return self.quantity * self.price_at_purchase

    def __str__(self):
        return f"{self.quantity} x {self.furniture.name} in Order #{self.order.order_number or self.order.id}"

    class Meta:
        unique_together = ('order', 'furniture')

@receiver(post_save, sender=Order)
def update_user_amount_on_order_delivery(sender, instance, created, **kwargs):
    # Store old status values before saving for comparison in post_save
    if not created:
        try:
            old_instance = sender.objects.get(pk=instance.pk)
            instance._previous_status = old_instance.status
            instance._previous_payment_status = old_instance.payment_status
        except sender.DoesNotExist:
            pass # Should not happen in a typical update flow

    if not instance.user:
        return

    # Handle the initial creation and immediate 'Delivered'/'Completed' status
    if created and instance.status == 'Delivered' and instance.payment_status == 'Completed':
        instance.user.add_amount_and_update_level(instance.total_amount)
        return

    # Handle status change from non-Delivered/Completed to Delivered/Completed
    previous_status = getattr(instance, '_previous_status', None)
    previous_payment_status = getattr(instance, '_previous_payment_status', None)

    if (
        instance.status == 'Delivered' and instance.payment_status == 'Completed' and
        (previous_status != 'Delivered' or previous_payment_status != 'Completed')
    ):
        instance.user.add_amount_and_update_level(instance.total_amount)

################################log model for membership change################################
class UserMembershipLog(models.Model):
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE)
    old_level = models.CharField(max_length=20)
    new_level = models.CharField(max_length=20)
    changed_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.username}: {self.old_level} → {self.new_level} on {self.changed_at:%Y-%m-%d}"
