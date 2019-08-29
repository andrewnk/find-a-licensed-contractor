<template>
  <div id="finder-app">
    <div class="filter-by">
      <div class="search">
        <input
          id="search-bar"
          v-model="search"
          class="search-field"
          type="text"
          placeholder="Search by license holder, company, or number"
        ><input
          ref="archive-search-bar"
          type="submit"
          class="search-submit"
          value="Search"
        >
      </div>
      <div class="select-license-type">
        <v-select    
          ref="contractorSelect"
          v-model="licenseType"
          label="license_type"
          placeholder="All contractor types"
          :options="licenseTypes"
        />
      </div>
    </div>
    <div
      v-show="loading"
      class="mtm center"
    >
      <i class="fas fa-spinner fa-spin fa-3x" />
    </div>
    <div
      v-show="!loading && emptyResponse"
      class="h3 mtm center"
    >
      Sorry, there are no results.
    </div>
    <div
      v-show="failure"
      class="h3 mtm center"
    >
      Sorry, there was a problem. Please try again.
    </div>
    <div
      v-if="!loading && !emptyResponse && !failure"
      class="table-container"
    >
      <table
        v-if="filteredLicenses.length"
        data-sticky-container
      >
        <thead
          class="sticky center"
          data-sticky
          data-top-anchor="filter-results:bottom"
          data-btm-anchor="page:bottom"
          data-options="marginTop:4.8;"
        >
          <tr>
            <th class="license-holder">
              <span>License Holder</span>
            </th>
            <th>
              <span>Company Name</span>
            </th>
            <th>
              <span>Special Categories</span>
            </th>
            <th>
              <span>Contractor Type</span>
            </th>
            <th>
              <span>License #</span>
            </th>
          </tr>
        </thead>
      
        <tr
          v-for="license in filteredLicenses"
          :key="license.licensenumber"
          class="license-row" 
        >
          <td>
            {{ license.contactname | upperCase }}
          </td>
          <td>
            {{ license.companyname | upperCase }}
          </td>
          <td>
            {{ license.icccategory }}
          </td>
          <td>
            {{ license.licensetype | titleCase }}
          </td>
          <td>
            {{ license.licensenumber }}
          </td>
        </tr>
      </table>
    </div>
  </div>
</template>

<script>
import Vue from "vue";
import axios from "axios";
import vSelect from 'vue-select';
import VuePaginate from "vue-paginate";
import VueFuse from "vue-fuse";

Vue.use(VuePaginate);
Vue.use(VueFuse);

const serviceURL = "https://data.phila.gov/carto/api/v2/sql?q=";
const query_base = "SELECT contactname, companyname, icccategory, licensenumber, licensetype FROM li_trade_licenses WHERE licensestatus = 'ACTIVE'";

export default {
  name: "FindALicensedContractor",
  components: { 
    vSelect,
  },
  filters: {
    'upperCase': function(value) {
      if (value) {
        return value.toUpperCase();
      }
    },

    'titleCase': function(str) {
      return str.replace(/\w\S*/g, function(txt){
        return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase();
      });
    },
  },
  data: function() {
    return {
      search: '',
      licenseType: '',
      licenses: {},
      licenseTypes: [],
      filteredLicenses: [],
      loading: true,
      emptyResponse: false,
      failure: false,
      searchOptions: {
        shouldSort: false, 
        threshold: 0.1, 
        keys: [
          'contactname',
          'companyname',
          'icccategory',
          'licensenumber',
        ],
      },
      contractorOptions: {
        shouldSort: false, 
        threshold: 0.0, 
        keys: [
          'licensetype',
        ],
      },
    };
  },
  computed: { 
    
  },

  watch: {
    licenseType: function() {
      this.filter();
    },

    search: function() {
      this.filter();
    },
  },

  mounted: function() {
    this.getAllLicenses();
  },

  methods: {

    toTitleCase: function(str) {
      return str.replace(/\w\S*/g, function(txt){
        return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase();
      });
    },
    

    getAllLicenses: function() {
      {
        axios
          .get(serviceURL+query_base)
          .then(response => {
            this.licenses = response.data;
            this.filteredLicenses = this.licenses.rows;
            this.loading = false;
            this.getLicenseTypes();
          })
          .catch(e => {
            window.console.log(e);
            this.failure = true;
            this.loading = false;
          });
      }
    },

    getLicenseTypes: function() {
      this.licenses.rows.forEach((license) => {
        let newLicenseType = license.licensetype;
        if (newLicenseType !== null && newLicenseType !== '') {
          this.licenseTypes.push(this.toTitleCase(newLicenseType));
        }
      });

      this.licenseTypes =  this.licenseTypes.filter((item, index) => this.licenseTypes.indexOf(item) === index).sort();

    },

    filterBySearch: function () {
      if (this.search !== '' && this.search !== null ) {
        this.$search(this.search, this.filteredLicenses, this.searchOptions).then(licenses => {
          this.filteredLicenses = licenses;
        }); 
      } 
    },

    filterByType: function() {
      if (this.licenseType !== '' && this.licenseType !== null) {
        this.$search(this.licenseType, this.filteredLicenses, this.contractorOptions).then(licenses => {
          this.filteredLicenses = licenses;
        });
      }
    },

    filter: async function() {
      this.filteredLicenses = this.licenses.rows;
      await this.filterByType();
      await this.filterBySearch();
    },

    
  },
};
</script>

<style lang="scss" >

@import 'node_modules/vue-select/dist/vue-select';


#finder-app {
  max-width: 85%;
  margin: 0 auto;
}

.filter-by {
  display: flex;
  flex-direction: row;
   position: sticky;
   position: -webkit-sticky;
  top: 0;
    z-index:100;
    width: 100%;
    background-color: white;
    padding-top: 10px;

  .search{
    width: 50%;
    margin-right: 5px;
  }

  .select-license-type {
    width: 50%;
    margin-left: 5px;
    .v-select {
      padding-top: 5px;
    }
  }
}

.table-container {
  
  .license-holder {
    width: 40%
  }
}

</style>