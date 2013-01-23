require 'rinruby'

sample_size = 10

R.eval <<EOF
        x <- rnorm(#{sample_size})
EOF

summary_of_x = R.pull "as.numeric(summary(x))"

puts "answer #{summary_of_x}"