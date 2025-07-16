from django.shortcuts import render, redirect

from customize.forms import WardrobeDesignForm

def create_wardrobe(request):
    if request.method == 'POST':
        form = WardrobeDesignForm(request.POST)
        if form.is_valid():
            wardrobe = form.save()
            return redirect('wardrobe_detail', pk=wardrobe.pk)
    else:
        form = WardrobeDesignForm()
    return render(request, 'create_wardrobe.html', {'form': form})

def wardrobe_detail(request, pk):
    from django.shortcuts import get_object_or_404
    wardrobe = get_object_or_404(WardrobeDesign, pk=pk)
    return render(request, 'wardrobe_detail.html', {'wardrobe': wardrobe})

from django.shortcuts import render, get_object_or_404
from .models import WardrobeDesign

def wardrobe_3d_view(request, pk):
    wardrobe = get_object_or_404(WardrobeDesign, pk=pk)
    return render(request, 'wardrobe_3d.html', {'wardrobe': wardrobe})
