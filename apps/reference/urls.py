from django.urls import path

from .views import (BeeSpeciesList, CropList, DiseaseList, DiseaseSymptomMatrix,
                    FarmerList, FloraList, MapDataView, MonthList, OutbreakList,
                    SymptomList)

urlpatterns = [
    path('diseases/', DiseaseList.as_view()),
    path('disease-symptoms/', DiseaseSymptomMatrix.as_view()),
    path('symptoms/', SymptomList.as_view()),
    path('flora/', FloraList.as_view()),
    path('months/', MonthList.as_view()),
    path('crops/', CropList.as_view()),
    path('bee-species/', BeeSpeciesList.as_view()),
    path('outbreaks/', OutbreakList.as_view()),
    path('farmers/', FarmerList.as_view()),
    path('map-farmers/', MapDataView.as_view()),
]
