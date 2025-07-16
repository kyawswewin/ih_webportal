from django.db import models
from decimal import Decimal

class Material(models.Model):
    name = models.CharField(max_length=100)
    
    # Specific texture fields for different parts
    texture_body = models.ImageField(upload_to='materials/textures/body/', blank=True, null=True, help_text="Texture for the wardrobe's main body.")
    texture_door = models.ImageField(upload_to='materials/textures/door/', blank=True, null=True, help_text="Texture for the wardrobe doors.")
    texture_handle = models.ImageField(upload_to='materials/textures/handle/', blank=True, null=True, help_text="Texture for the handles.")
    
    color_hex = models.CharField(max_length=7, default="#8B4513", help_text="Hexadecimal color code (e.g., #RRGGBB).") 
    
    # Pricing fields - crucial for accurate costing
    price_per_sqft = models.DecimalField(max_digits=10, decimal_places=2, default=0.00, help_text="Price per square foot for body/door/shelf usage.")
    price_per_unit = models.DecimalField(max_digits=10, decimal_places=2, default=0.00, help_text="Price per single unit for accessories like handles.")

    class Meta:
        verbose_name = "Material"
        verbose_name_plural = "Materials"

    def __str__(self):
        return self.name

class WardrobeDesign(models.Model):
    # Foreign Keys linking to Material for different components
    body_material = models.ForeignKey(
        Material, 
        on_delete=models.CASCADE, 
        related_name='body_designs',
        help_text="Select the material for the main body/carcass of the wardrobe."
    )
    door_material = models.ForeignKey(
        Material, 
        on_delete=models.CASCADE, 
        related_name='door_designs',
        help_text="Select the material for the wardrobe doors."
    )
    handle_material = models.ForeignKey(
        Material, 
        on_delete=models.SET_NULL, # Handles can be optional or have no specific material
        related_name='handle_designs', 
        blank=True, 
        null=True,
        help_text="Select the material for the handles. Its 'texture_handle' will be used."
    )
    shelf_material = models.ForeignKey(
        Material, 
        on_delete=models.SET_NULL, 
        related_name='shelf_designs', 
        blank=True, 
        null=True,
        help_text="Select the material for the internal shelves."
    )

    # Dimensions
    width = models.FloatField(help_text="Width of the wardrobe in feet (e.g., 5.0).")
    height = models.FloatField(help_text="Height of the wardrobe in feet (e.g., 7.5).")
    depth = models.FloatField(help_text="Depth of the wardrobe in feet (e.g., 2.0).")
    
    shelf_count = models.IntegerField(default=3, help_text="Number of internal shelves.")
    handle_count = models.IntegerField(default=2, help_text="Number of handles for the wardrobe.") # Assuming two doors usually

    # Additional color for shelves (if not tied to shelf_material's color_hex)
    shelf_color_hex = models.CharField(max_length=7, default="#D2B48C", help_text="Hexadecimal color for shelves if 'shelf_material' doesn't dictate it.") 

    # Cost and Timestamps
    estimated_cost = models.DecimalField(max_digits=10, decimal_places=2, blank=True, null=True, help_text="Automatically calculated estimated cost of the design.")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Wardrobe Design"
        verbose_name_plural = "Wardrobe Designs"

    def save(self, *args, **kwargs):
        # Calculate areas (example - adjust based on your actual wardrobe structure)
        # Assuming body covers perimeter + back, doors cover front, shelves are flat
        
        # Body Area (simplified: sum of visible panels, e.g., 2 sides, top, bottom, back)
        # This is a very rough estimate; in real-world, you'd calculate exact panel dimensions.
        body_area_sqft = (2 * self.height * self.depth) + (self.width * self.depth) + (self.width * self.height) # Sides, top/bottom, back

        # Door Area (assuming two doors for full width)
        door_area_sqft = self.width * self.height # Area of the front face (could be split for multiple doors)

        # Shelf Area
        shelf_area_sqft = Decimal(str(self.width * self.depth * self.shelf_count)) # Each shelf is width * depth

        calculated_cost = Decimal('0.00')

        # Calculate Body Cost
        if self.body_material:
            calculated_cost += self.body_material.price_per_sqft * Decimal(str(body_area_sqft))
        
        # Calculate Door Cost
        if self.door_material:
            calculated_cost += self.door_material.price_per_sqft * Decimal(str(door_area_sqft))

        # Calculate Shelf Cost
        if self.shelf_material:
            calculated_cost += self.shelf_material.price_per_sqft * shelf_area_sqft

        # Calculate Handle Cost
        if self.handle_material and self.handle_material.price_per_unit > 0:
            calculated_cost += self.handle_material.price_per_unit * self.handle_count

        self.estimated_cost = calculated_cost
        super().save(*args, **kwargs)

    def __str__(self):
        return f"Wardrobe Design {self.id} (Body: {self.body_material.name if self.body_material else 'N/A'})"