from django.contrib import admin, messages
from django.utils.html import format_html
from .models import Brand, CategoryLog, Furniture, Category,CustomUser, Order, OrderItem, Sponsor
from django.contrib.auth.admin import UserAdmin
from .forms import CustomUserCreationForm


@admin.register(Brand)
class BrandAdmin(admin.ModelAdmin):
    list_display = ('name', 'slug', 'logo')
    prepopulated_fields = {'slug': ('name',)}

@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    list_display = ('name', 'parent', '__str__')

    def save_model(self, request, obj, form, change):
        super().save_model(request, obj, form, change)

        action = 'updated' if change else 'created'
        CategoryLog.objects.create(
            category=obj,
            category_name=obj.name,
            action=action,
            changed_by=request.user 
        )

    def delete_model(self, request, obj):
        CategoryLog.objects.create(
            category_name=obj.name, 
            action='deleted',
            changed_by=request.user,
        )
        super().delete_model(request, obj)

@admin.register(Furniture)
class FurnitureAdmin(admin.ModelAdmin):
    list_display = ('item_code','name', 'category', 'price', 'featured','is_visible', 'image_preview')
    list_filter = ('category', 'featured','is_visible')
    search_fields = ('item_code','name', 'description')
    list_editable = ('featured','is_visible')
    readonly_fields = ('image_preview',)

    def image_preview(self, obj):
        if obj.image:
            return format_html('<img src="{}" style="height: 100px; border-radius: 8px;" />', obj.image.url)
        return "No image"
    image_preview.short_description = 'Preview'



class CustomUserAdmin(UserAdmin):
    add_form = CustomUserCreationForm
    model = CustomUser
    list_display = (
        'c_code', 'username', 'amount', 'member_level', 'email',
        'phone', 'nrc', 'dob', 'createdby', 'is_staff'
    )
    search_fields = ('username', 'email', 'phone', 'c_code', 'nrc')

    fieldsets = (
        ('Credentials', {'fields': ('username', 'password')}), # Essential: Username and password
        ('Personal Info', {'fields': ('first_name', 'last_name', 'email','phone', 'nrc', 'dob', 'c_code','amount', 'member_level', 'createdby')}),
        ('Permissions', {'fields': ('is_active', 'is_staff', 'is_superuser', 'groups', 'user_permissions'),}),
        ('Important dates', {'fields': ('last_login', 'date_joined')}),
    )

    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': ('username', 'password', 'password2'), # For new user creation, password and confirmation
        }),
        ('Personal Info', {
            'fields': (
                'first_name', 'last_name', 'email',
                'phone', 'nrc', 'dob', 'c_code',
                'amount', 'member_level', 'createdby'
            )
        }),
        ('Permissions', {
            'fields': ('is_active', 'is_staff', 'is_superuser', 'groups', 'user_permissions'),
        }),
    )


class OrderItemInline(admin.TabularInline):
    model = OrderItem
    extra = 0
    fields = ('furniture_item_code', 'furniture', 'quantity', 'price_at_purchase')
    readonly_fields = ('furniture_item_code','price_at_purchase')
    raw_id_fields = ('furniture',)
    def furniture_item_code(self, obj):
        return obj.furniture.item_code if obj.furniture else '-'
    furniture_item_code.short_description = 'Item Code'

@admin.register(Order)
class OrderAdmin(admin.ModelAdmin):
    list_display = ('id','order_number', 'user', 'customer_name', 'total_amount', 'status', 'payment_status', 'created_at')
    list_filter = ('status', 'payment_status', 'created_at')
    search_fields = ('customer_name', 'user__username', 'id')
    readonly_fields = ('created_at', 'updated_at', 'total_amount')
    inlines = [OrderItemInline]

    def save_model(self, request, obj, form, change):
        user = obj.user
        old_level = user.member_level if user else None
        was_delivered = obj.status == 'Delivered'
        was_paid = obj.payment_status == 'Completed'

        super().save_model(request, obj, form, change)

        obj.total_amount = obj.calculate_total_amount()
        obj.save(update_fields=['total_amount'])

        if user and was_delivered and was_paid:
            old_amount = user.amount
            user.add_amount_and_update_level(obj.total_amount) 
            user.refresh_from_db()
            if old_level != user.member_level:
                self.message_user(
                    request,
                    f"🎉 Membership upgraded for {user.username} from {old_level} to {user.member_level}!",
                    level=messages.SUCCESS
                )
from .models import MemberLevel

@admin.register(MemberLevel)
class MemberLevelAdmin(admin.ModelAdmin):
    list_display = ('name', 'min_price', 'max_price', 'allowance', 'image_tag')
    search_fields = ('name',)
    list_filter = ('name',)
    readonly_fields = ('image_tag',)

    def image_tag(self, obj):
        if obj.image:
            return format_html('<img src="{}" style="height:40px; border-radius:6px;" />', obj.image.url)
        return "-"
    image_tag.short_description = "Image"

admin.site.register(CustomUser, CustomUserAdmin)


@admin.register(Sponsor)
class SponsorAdmin(admin.ModelAdmin):
    list_display = ('name', 'website')
    search_fields = ('name',)

    
from django.contrib import admin
from .models import ExchangeRate, ExchangeRateLog

class ExchangeRateAdmin(admin.ModelAdmin):
    list_display = ('currency', 'rate', 'last_updated')

    def save_model(self, request, obj, form, change):
        obj._changed_by = request.user  # Custom attribute to pass user
        super().save_model(request, obj, form, change)

admin.site.register(ExchangeRate, ExchangeRateAdmin)
admin.site.register(ExchangeRateLog)