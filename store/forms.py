from django import forms
from .models import Brand, Category, CustomUser, Furniture
from django.contrib.auth.forms import UserCreationForm

class CustomUserCreationForm(UserCreationForm):
    email = forms.EmailField(required=True)
    phone = forms.CharField(required=False)
    nrc = forms.CharField(required=False)
    dob = forms.DateField(required=False, widget=forms.DateInput(attrs={'type': 'date'}))

    class Meta(UserCreationForm.Meta): 
        model = CustomUser
        fields = UserCreationForm.Meta.fields + (
            'email', 'phone', 'nrc', 'dob', 
        )
    def save(self, commit=True):
        user = super().save(commit=False)
        user.email = self.cleaned_data['email']
        user.phone = self.cleaned_data.get('phone', '')
        user.nrc = self.cleaned_data.get('nrc', '')
        user.dob = self.cleaned_data.get('dob', None)
        user.c_code = self.cleaned_data.get('c_code', '')
        user.createdby = 'website'

        if commit:
            user.save()
        return user

class OrderForm(forms.Form):
    customer_name = forms.CharField(max_length=100)
    customer_address = forms.CharField(widget=forms.Textarea)
    customer_phone = forms.CharField(max_length=20)
    payment_method = forms.CharField(max_length=50, initial='Cash on Delivery')


class FurnitureForm(forms.ModelForm):
    class Meta:
        model = Furniture
        fields = ['category', 'brand', 'name', 'item_code', 'description', 'price', 'image', 'image_2', 'image_3', 'featured','is_visible']
        widgets = {
            'description': forms.Textarea(attrs={'rows': 4}),
            'item_code': forms.TextInput(attrs={'placeholder': 'e.g., xxx-xxx-xx'})
        }

    category = forms.ModelChoiceField(
        queryset=Category.objects.all().order_by('name'),
        empty_label="--- Select Category ---"
    )
    brand = forms.ModelChoiceField(
        queryset=Brand.objects.all().order_by('name'),
        empty_label="--- Select Brand ---",
        required=False 
    )

class CustomUserUpdateForm(forms.ModelForm):
    class Meta:
        model = CustomUser
        fields = ['first_name', 'last_name', 'email', 'phone', 'nrc', 'dob', 'is_active', 'is_staff']
        widgets = {
            'dob': forms.DateInput(attrs={'type': 'date'}),
        }

class CategoryForm(forms.ModelForm):
    class Meta:
        model = Category
        fields = ['name', 'parent']
