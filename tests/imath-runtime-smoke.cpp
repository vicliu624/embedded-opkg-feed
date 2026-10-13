#include <Imath/half.h>
#include <Imath/ImathVec.h>
#include <Imath/ImathMatrix.h>
#include <cmath>
#include <cstdio>

int main()
{
    const Imath::half value(1.5f);
    if (value.bits() != 0x3e00 || float(value) != 1.5f) return 1;
    Imath::half roundtrip;
    roundtrip.setBits(value.bits());
    if (float(roundtrip) != 1.5f) return 2;
    Imath::V3f a(1, 0, 0), b(0, 1, 0);
    if (a.cross(b) != Imath::V3f(0, 0, 1)) return 3;
    Imath::M44f transform;
    transform.translate(Imath::V3f(2, 3, 4));
    Imath::V3f input(1, 2, 3), output;
    transform.multVecMatrix(input, output);
    if (output != Imath::V3f(3, 5, 7)) return 4;
    transform.inverse().multVecMatrix(output, output);
    if ((output - input).length() > 0.00001f) return 5;
    std::puts("Imath target half encoding and geometry transforms: PASS");
    return 0;
}
