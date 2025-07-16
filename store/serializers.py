from rest_framework import serializers

from .models import CustomUser, Order, OrderItem,CustomUser
from .models import Furniture, Category

class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = ['id', 'name']

class FurnitureSerializer(serializers.ModelSerializer):
    category = CategorySerializer()
    image = serializers.SerializerMethodField()  # <- this line

    class Meta:
        model = Furniture
        fields = ['id', 'name', 'price', 'category', 'description', 'featured', 'image','item_code']

    def get_image(self, obj):
        request = self.context.get('request')
        if obj.image and hasattr(obj.image, 'url'):
            return request.build_absolute_uri(obj.image.url) if request else obj.image.url
        return None


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)

    class Meta:
        model = CustomUser
        fields = ('username', 'email', 'password')

    def create(self, validated_data):
        user = CustomUser(
            username=validated_data['username'],
            email=validated_data['email'],
            createdby='mobile'  # Set createdby for mobile
        )
        user.set_password(validated_data['password'])
        user.save()
        return user

class UserProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = CustomUser
        fields = ['username', 'email', 'phone','nrc', 'dob',"c_code"]


class CartItemSerializer(serializers.Serializer):
    furniture_id = serializers.IntegerField()
    quantity = serializers.IntegerField(min_value=1)

class OrderItemSerializer(serializers.ModelSerializer):
    furniture_name = serializers.CharField(source='furniture.name', read_only=True)
    order_number = serializers.CharField(source='order.order_number', read_only=True) 

    class Meta:
        model = OrderItem
        fields = ['id','order_number', 'furniture', 'furniture_name', 'quantity', 'price_at_purchase']
        read_only_fields = ['id', 'price_at_purchase'] # Also 'furniture_name' implicitly due to 'source' and 'read_only=True'

class OrderSerializer(serializers.ModelSerializer):
    items = OrderItemSerializer(many=True, read_only=True)
    user_username = serializers.CharField(source='user.username', read_only=True)

    class Meta:
        model = Order
        fields = [
            'id', 'user', 'user_username', 'customer_name', 'customer_address', 'customer_phone',
            'status', 'created_at', 'updated_at', 'total_amount',
            'payment_status', 'payment_method', 'items','order_number'
        ]
        read_only_fields = ['id', 'user', 'user_username', 'created_at', 'updated_at', 'total_amount']

