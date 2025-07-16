from django import forms

from customize.models import Material, WardrobeDesign

class WardrobeDesignForm(forms.ModelForm):
    # Use ModelChoiceField for each specific material type
    body_material = forms.ModelChoiceField(queryset=Material.objects.all(), empty_label="Select Body Material", required=True)
    door_material = forms.ModelChoiceField(queryset=Material.objects.all(), empty_label="Select Door Material", required=True)
    accessory_material = forms.ModelChoiceField(queryset=Material.objects.all(), empty_label="Select Accessory Material", required=False) # Optional

    class Meta:
        model = WardrobeDesign
        # Update fields to use the new separate material fields
        fields = ['body_material', 'door_material', 'accessory_material', 'width', 'height', 'depth', 'shelf_count']
        widgets = {
            'width': forms.NumberInput(attrs={'step': '0.1', 'min': '1', 'max': '10'}),
            'height': forms.NumberInput(attrs={'step': '0.1', 'min': '1', 'max': '10'}),
            'depth': forms.NumberInput(attrs={'step': '0.1', 'min': '0.5', 'max': '5'}),
            'shelf_count': forms.NumberInput(attrs={'step': '1', 'min': '0', 'max': '10'}),
        }

