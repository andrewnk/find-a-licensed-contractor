<template>
  <div class="example" />
</template>

<script>
import Vue from "vue";
import axios from "axios";

import VuePaginate from "vue-paginate";
import VueFuse from "vue-fuse";

Vue.use(VuePaginate);
Vue.use(VueFuse);

const endpoint = "https://data.phila.gov/carto/api/v2/sql?q=";

export default {
  name: "FindALicensedContractor",
  components: { 
    
  },
  filters: {
    
  },
  data: function() {
    return {
    
    };
  },
  computed: { 
    
  },

  watch: {
   
  },

  created: {
    
  },

  methods: {
    
  },
};
</script>

<style lang="scss" >
.example {
  display: none;
}

.appnav {
  display: none;
}
</style>