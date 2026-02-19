from .naive import IMPLEMENTATIONS as _naive
from .numba_impl import IMPLEMENTATIONS as _numba
from .numpy_impl import IMPLEMENTATIONS as _numpy
from .opencv_impl import IMPLEMENTATIONS as _opencv
from .pillow_impl import IMPLEMENTATIONS as _pillow

ALL_IMPLEMENTATIONS = _numpy + _opencv + _pillow + _numba + _naive
