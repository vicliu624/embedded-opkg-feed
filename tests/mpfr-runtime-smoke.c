#include <mpfr.h>
#include <string.h>

int main(void) {
    if (strcmp(mpfr_get_version(), "4.2.2")) return 1;
    mpfr_t lower, upper, exact, result;
    mpfr_inits2(256, lower, upper, exact, result, (mpfr_ptr)0);
    mpfr_set_ui(exact, 1, MPFR_RNDN);
    mpfr_div_ui(lower, exact, 3, MPFR_RNDD);
    mpfr_div_ui(upper, exact, 3, MPFR_RNDU);
    if (mpfr_cmp(lower, upper) >= 0) return 2;
    mpfr_mul_ui(result, lower, 3, MPFR_RNDN);
    if (mpfr_cmp_ui(result, 1) > 0) return 3;
    mpfr_mul_ui(result, upper, 3, MPFR_RNDN);
    if (mpfr_cmp_ui(result, 1) < 0) return 4;
    mpfr_set_ui(exact, 16, MPFR_RNDN);
    mpfr_sqrt(result, exact, MPFR_RNDN);
    if (mpfr_cmp_ui(result, 4)) return 5;
    mpfr_set_ui(exact, 0, MPFR_RNDN);
    mpfr_exp(result, exact, MPFR_RNDN);
    if (mpfr_cmp_ui(result, 1)) return 6;
    mpfr_set_si(exact, -1, MPFR_RNDN);
    mpfr_sqrt(result, exact, MPFR_RNDN);
    if (!mpfr_nan_p(result)) return 7;
    mpfr_clears(lower, upper, exact, result, (mpfr_ptr)0);
    mpfr_free_cache();
    return 0;
}
