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

# signals.py

from django.db.models.signals import pre_save, post_save
from django.dispatch import receiver
from .models import ExchangeRate, ExchangeRateLog

@receiver(pre_save, sender=ExchangeRate)
def track_old_exchange_rate(sender, instance, **kwargs):
    if instance.pk:
        try:
            old_instance = ExchangeRate.objects.get(pk=instance.pk)
            instance._old_rate = old_instance.rate
        except ExchangeRate.DoesNotExist:
            instance._old_rate = None
    else:
        instance._old_rate = None

@receiver(post_save, sender=ExchangeRate)
def log_exchange_rate_change(sender, instance, created, **kwargs):
    if created:
        return  # Only log updates

    if hasattr(instance, '_old_rate') and instance._old_rate != instance.rate:
        ExchangeRateLog.objects.create(
            exchange_rate=instance,
            currency=instance.currency,
            old_rate=instance._old_rate,
            new_rate=instance.rate,
            changed_by=getattr(instance, '_changed_by', None)  # Use user from admin
        )
