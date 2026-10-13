#include <ruy/ruy.h>
#include <cmath>
#include <cstdio>

int main() {
    const float a[] = {1, 2, 3, 4};
    const float b[] = {5, 6, 7, 8};
    float result[4] = {};
    ruy::Matrix<float> lhs, rhs, dst;
    ruy::MakeSimpleLayout(2, 2, ruy::Order::kRowMajor, lhs.mutable_layout());
    ruy::MakeSimpleLayout(2, 2, ruy::Order::kRowMajor, rhs.mutable_layout());
    ruy::MakeSimpleLayout(2, 2, ruy::Order::kRowMajor, dst.mutable_layout());
    lhs.set_data(a);
    rhs.set_data(b);
    dst.set_data(result);
    ruy::Context context;
    context.set_max_num_threads(1);
    ruy::MulParams<float, float> params;
    ruy::Mul(lhs, rhs, params, &context, &dst);
    const float expected[] = {19, 22, 43, 50};
    for (int i = 0; i < 4; ++i)
        if (!std::isfinite(result[i]) || std::fabs(result[i] - expected[i]) > 1e-5f) return 1;
    std::puts("ruy target matrix multiplication passed");
    return 0;
}
