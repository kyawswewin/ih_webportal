from django.contrib import admin

from customize.models import Material, WardrobeDesign
class MaterialAdmin(admin.ModelAdmin):
    list_display = ('name', 'price_per_sqft', 'price_per_unit', 'display_body_texture', 'display_door_texture', 'display_handle_texture')
    readonly_fields = ('display_body_texture', 'display_door_texture', 'display_handle_texture')

    def display_body_texture(self, obj):
        if obj.texture_body:
            from django.utils.html import format_html
            return format_html('<img src="{}" width="50" height="50" style="max-width: 100px; max-height: 100px;" />', obj.texture_body.url)
        return "No Texture"
    display_body_texture.short_description = "Body Texture"

    def display_door_texture(self, obj):
        if obj.texture_door:
            from django.utils.html import format_html
            return format_html('<img src="{}" width="50" height="50" style="max-width: 100px; max-height: 100px;" />', obj.texture_door.url)
        return "No Texture"
    display_door_texture.short_description = "Door Texture"

    def display_handle_texture(self, obj):
        if obj.texture_handle:
            from django.utils.html import format_html
            return format_html('<img src="{}" width="50" height="50" style="max-width: 100px; max-height: 100px;" />', obj.texture_handle.url)
        return "No Texture"
    display_handle_texture.short_description = "Handle Texture"

admin.site.register(Material, MaterialAdmin)

class WardrobeDesignAdmin(admin.ModelAdmin):
    list_display = ('id', 'body_material', 'door_material', 'handle_material', 'shelf_material', 'width', 'height', 'estimated_cost', 'created_at')
    list_filter = ('body_material', 'door_material', 'handle_material', 'shelf_material')
    search_fields = ('body_material__name', 'door_material__name')
    readonly_fields = ('estimated_cost', 'created_at', 'updated_at')

admin.site.register(WardrobeDesign, WardrobeDesignAdmin)