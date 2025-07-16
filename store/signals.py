from django.db.models.signals import pre_save, post_save
from django.dispatch import receiver
from .models import Order

# Store previous values before save
@receiver(pre_save, sender=Order)
def store_previous_order_status(sender, instance, **kwargs):
    if instance.pk:
        try:
            old_instance = sender.objects.get(pk=instance.pk)
            instance._previous_status = old_instance.status
            instance._previous_payment_status = old_instance.payment_status
        except sender.DoesNotExist:
            instance._previous_status = None
            instance._previous_payment_status = None
