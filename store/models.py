from django.db import models
from django.contrib.auth.models import AbstractUser
from django.db.models.signals import post_save
from django.dispatch import receiver
from django.db.models import F # Import F for atomic updates
from django.db import transaction
from django.utils.text import slugify


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
        ('INHOUSE', 'Inhouse'),
        ('CLASSIC', 'Classic'),
        ('GOLD', 'Gold'),
        ('PLATINUM', 'Platinum'),
        ('DIAMOND', 'Diamond'),
        ('VVIP', 'VVIP'),
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
        levels = MemberLevel.objects.all().order_by('min_price')

        for level in levels:
            if level.min_price >= self.amount <= level.max_price:
                self.member_level = level.name
                break

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
class Category(models.Model):
    name = models.CharField(max_length=100)
    parent = models.ForeignKey(
        'self',
        on_delete=models.SET_NULL, 
        null=True,
        blank=True,
        related_name='children'
    )
    def __str__(self):
        if self.parent:
            return f"{self.parent.name} > {self.name}"
        return self.name
    class Meta:
        verbose_name_plural = "Categories"
        ordering = ['parent__name', 'name']

class CategoryLog(models.Model):
    category = models.ForeignKey(Category, on_delete=models.SET_NULL, null=True, blank=True,
                                 help_text="The category that was affected (can be null if category was deleted).")
    category_name = models.CharField(max_length=100, help_text="Name of the category at the time of the log.")
    action = models.CharField(max_length=20, choices=[
        ('created', 'Created'),
        ('updated', 'Updated'),
        ('deleted', 'Deleted'),
    ], help_text="Type of action performed on the category.")
    changed_by = models.ForeignKey(CustomUser, on_delete=models.SET_NULL, null=True, blank=True,
                                  help_text="The user who performed the action.")
    timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-timestamp'] 
        verbose_name = "Category Log"
        verbose_name_plural = "Category Logs"

    def __str__(self):
        category_info = self.category_name if self.category_name else "Unknown Category"
        if self.changed_by:
            return f"[{self.timestamp.strftime('%Y-%m-%d %H:%M')}] {category_info} {self.action} by {self.changed_by.username}"
        return f"[{self.timestamp.strftime('%Y-%m-%d %H:%M')}] {category_info} {self.action}"

@receiver(post_save, sender=Category)
def log_category_save(sender, instance, created, **kwargs):
    if kwargs.get('raw', False): 
        return

    action_type = 'created' if created else 'updated'
    
    user = kwargs.get('user', None) 
   
    CategoryLog.objects.create(
        category=instance,
        category_name=instance.name,
        action=action_type,
        changed_by=user, 
    )

@receiver(models.signals.pre_delete, sender=Category)
def log_category_delete(sender, instance, **kwargs):
   
    user = kwargs.get('user', None) 
   
    CategoryLog.objects.create(
        category_name=instance.name, 
        action='deleted',
        changed_by=user, 
    )

class Brand(models.Model):
    name = models.CharField(max_length=100, unique=True)
    slug = models.SlugField(unique=True, help_text="A URL-friendly identifier for the brand, automatically generated if left blank.")
    logo = models.ImageField(upload_to='brand_logos/', blank=True, null=True,
                             help_text="Optional: Upload a logo for the brand.")
    description = models.TextField(blank=True, help_text="Optional: A short description of the brand.")
    def save(self, *args, **kwargs):
        if not self.slug: # Automatically generate slug if not set
            self.slug = slugify(self.name)
        super().save(*args, **kwargs)
    class Meta:
        verbose_name_plural = "Brands"
        ordering = ['name']

    def __str__(self):
        return self.name
class Furniture(models.Model):
    category = models.ForeignKey(Category, on_delete=models.CASCADE)
    name = models.CharField(max_length=200)
    item_code = models.CharField(max_length=20, unique=True)
    description= models.TextField()
    price = models.DecimalField(max_digits=8 , decimal_places=2)
    image = models.ImageField(upload_to='furniture_images/', blank=True, null=True)
    image_2 = models.ImageField(upload_to='furniture_images/', blank=True, null=True)
    image_3 = models.ImageField(upload_to='furniture_images/', blank=True, null=True)

    featured = models.BooleanField(default=False)

    brand = models.ForeignKey(
            'Brand', 
            on_delete=models.SET_NULL, 
            null=True,
            blank=True,
            related_name='furniture_items', 
            help_text="The brand of this furniture item."
    )

    is_visible = models.BooleanField(
            default=True,
            help_text="Designates whether this furniture item should be visible on the website."
        )
    def __str__(self):
        return self.name
    class Meta:
        verbose_name_plural = "Furniture"


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


class OrderLog(models.Model):
    order = models.ForeignKey(Order, on_delete=models.SET_NULL, null=True, blank=True,
                              help_text="The order that was affected (can be null if order was deleted).")
    action = models.CharField(max_length=20, choices=[
        ('created', 'Created'),
        ('updated', 'Updated'),
        ('deleted', 'Deleted'),
    ], help_text="Type of action performed on the order.")
    changed_by = models.ForeignKey(CustomUser, on_delete=models.SET_NULL, null=True, blank=True,
                                  help_text="The user who performed the action.")
    timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-timestamp'] 
        verbose_name = "Order Log"
        verbose_name_plural = "Order Logs"

    def __str__(self):
        return f"[{self.timestamp.strftime('%Y-%m-%d %H:%M')}] Order {self.order.order_number or self.order.id} {self.action} by {self.changed_by.username}"

@receiver(post_save, sender=Order)
def log_order_save(sender, instance, created, **kwargs):   
    if created:
        action_type = 'created'
    else:
        action_type = 'updated'

    OrderLog.objects.create(
        order=instance,
        action=action_type,
        changed_by=instance.user, 
    )
@receiver(models.signals.pre_delete, sender=Order)
def log_order_delete(sender, instance, **kwargs):
    OrderLog.objects.create(
        order=instance,
        action='deleted',
        changed_by=instance.user, 
    )

@receiver(post_save, sender=Order)
def update_user_amount_on_order_delivery(sender, instance, created, **kwargs):
    if not created:
        try:
            old_instance = sender.objects.get(pk=instance.pk)
            instance._previous_status = old_instance.status
            instance._previous_payment_status = old_instance.payment_status
        except sender.DoesNotExist:
            pass 

    if not instance.user:
        return

    if created and instance.status == 'Delivered' and instance.payment_status == 'Completed':
        instance.user.add_amount_and_update_level(instance.total_amount)
        return

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

class MemberLevel(models.Model):
    LEVEL_CHOICES = [
        ('INHOUSE', 'Inhouse'),
        ('CLASSIC', 'Classic'),
        ('GOLD', 'Gold'),
        ('PLATINUM', 'Platinum'),
        ('DIAMOND', 'Diamond'),
        ('VVIP', 'VVIP'),
    ]
    name = models.CharField(max_length=20, choices=LEVEL_CHOICES, unique=True)
    image = models.ImageField(upload_to='member_levels/', blank=True, null=True)
    min_price = models.DecimalField(max_digits=12, decimal_places=2)
    max_price = models.DecimalField(max_digits=12, decimal_places=2)
    allowance = models.DecimalField(max_digits=12, decimal_places=2, help_text="Allowance for this level")

    def __str__(self):
        return self.get_name_display()
    
class Sponsor(models.Model):
    name = models.CharField(max_length=100)
    logo = models.ImageField(upload_to='sponsors/')
    description= models.CharField(max_length=255, blank=True, null=True)
    website = models.URLField(blank=True)

    def __str__(self):
        return self.name

class SponsorLog(models.Model):
    sponsor = models.ForeignKey(Sponsor, on_delete=models.SET_NULL, null=True, blank=True,
                                 help_text="The sponsor that was affected (can be null if sponsor was deleted).")
    sponsor_name = models.CharField(max_length=100, help_text="Name of the sponsor at the time of the log.")
    action = models.CharField(max_length=20, choices=[
        ('created', 'Created'),
        ('updated', 'Updated'),
        ('deleted', 'Deleted'),
    ], help_text="Type of action performed on the sponsor.")
    changed_by = models.ForeignKey(CustomUser, on_delete=models.SET_NULL, null=True, blank=True,
                                  help_text="The user who performed the action.")
    timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-timestamp'] 
        verbose_name = "Sponsor Log"
        verbose_name_plural = "Sponsor Logs"

    def __str__(self):
        sponsor_info = self.sponsor_name if self.sponsor_name else "Unknown Sponsor"
        if self.changed_by:
            return f"[{self.timestamp.strftime('%Y-%m-%d %H:%M')}] {sponsor_info} {self.action} by {self.changed_by.username}"
        return f"[{self.timestamp.strftime('%Y-%m-%d %H:%M')}] {sponsor_info} {self.action}"




class ExchangeRate(models.Model):
    currency = models.CharField(max_length=3, unique=True, help_text="e.g., USD, EUR, JPY")
    rate = models.DecimalField(max_digits=10, decimal_places=2)
    last_updated = models.DateTimeField(auto_now=True)
    

    created_by = models.ForeignKey(
        CustomUser,
        on_delete=models.SET_NULL, 
        null=True, 
        blank=True, 
        related_name='exchange_rates_changed', 
        help_text="The user who last created or modified this exchange rate."
    )

    def __str__(self):
        return f"{self.currency}: {self.rate}"

    class Meta:
        ordering = ['currency']
        verbose_name = "Exchange Rate"
        verbose_name_plural = "Exchange Rates"

class ExchangeRateLog(models.Model):
    exchange_rate = models.ForeignKey(ExchangeRate, on_delete=models.SET_NULL, null=True, blank=True,
                                       help_text="The exchange rate that was affected (can be null if rate was deleted).")
    currency = models.CharField(max_length=10, help_text="Currency code at the time of the log.")
    old_rate = models.DecimalField(max_digits=10, decimal_places=2, help_text="Old exchange rate before the change.")
    new_rate = models.DecimalField(max_digits=10, decimal_places=2, help_text="New exchange rate after the change.")
    changed_by = models.ForeignKey(CustomUser, on_delete=models.SET_NULL, null=True, blank=True,
                                   help_text="The user who performed the action.")
    timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-timestamp'] 
        verbose_name = "Exchange Rate Log"
        verbose_name_plural = "Exchange Rate Logs"

    def __str__(self):
        return f"[{self.timestamp.strftime('%Y-%m-%d %H:%M')}] {self.currency} rate changed from {self.old_rate} to {self.new_rate} by {self.changed_by.username}"    

